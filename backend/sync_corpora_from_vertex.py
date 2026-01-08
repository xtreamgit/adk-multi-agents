#!/usr/bin/env python3
"""
Sync corpora from Vertex AI RAG with local database.

This script:
1. Fetches all corpora from Vertex AI
2. Compares with database corpora
3. Adds new corpora from Vertex AI to database
4. Deactivates corpora in DB that don't exist in Vertex AI
5. Reactivates corpora that exist in both
6. Grants default group access to new corpora
"""

import os
import sys
from datetime import datetime

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

import vertexai
from vertexai import rag
from database.repositories.corpus_repository import CorpusRepository
from database.repositories.group_repository import GroupRepository
from rag_agent.config import PROJECT_ID, LOCATION

def sync_corpora():
    """Sync corpora from Vertex AI to database."""
    print(f"🔄 Syncing corpora from Vertex AI...")
    print(f"   Project: {PROJECT_ID}")
    print(f"   Location: {LOCATION}")
    print()
    
    # Initialize Vertex AI
    try:
        import google.auth
        credentials, _ = google.auth.default()
        vertexai.init(project=PROJECT_ID, location=LOCATION, credentials=credentials)
        print("✅ Vertex AI initialized")
    except Exception as e:
        print(f"❌ Failed to initialize Vertex AI: {e}")
        return False
    
    # Fetch corpora from Vertex AI
    try:
        vertex_corpora = list(rag.list_corpora())
        vertex_corpus_dict = {}
        
        print(f"\n📚 Found {len(vertex_corpora)} corpora in Vertex AI:")
        for corpus in vertex_corpora:
            # Extract display name from resource name
            # Format: projects/{project}/locations/{location}/ragCorpora/{corpus_id}
            display_name = corpus.display_name
            resource_name = corpus.name
            
            vertex_corpus_dict[display_name] = {
                'resource_name': resource_name,
                'display_name': display_name,
                'create_time': corpus.create_time
            }
            
            print(f"   - {display_name}")
            print(f"     Resource: {resource_name}")
            print(f"     Created: {corpus.create_time}")
        
        print()
        
    except Exception as e:
        print(f"❌ Failed to fetch corpora from Vertex AI: {e}")
        return False
    
    # Fetch corpora from database
    try:
        db_corpora = CorpusRepository.get_all(active_only=False)
        db_corpus_dict = {c['name']: c for c in db_corpora}
        
        print(f"💾 Found {len(db_corpora)} corpora in database:")
        for corpus in db_corpora:
            status = "active" if corpus['is_active'] else "inactive"
            print(f"   - {corpus['name']} ({status})")
        
        print()
        
    except Exception as e:
        print(f"❌ Failed to fetch corpora from database: {e}")
        return False
    
    # Sync logic
    vertex_names = set(vertex_corpus_dict.keys())
    db_names = set(db_corpus_dict.keys())
    
    # Corpora to add (in Vertex AI but not in DB)
    to_add = vertex_names - db_names
    
    # Corpora to deactivate (in DB but not in Vertex AI)
    to_deactivate = db_names - vertex_names
    
    # Corpora to reactivate/update (in both)
    to_update = vertex_names & db_names
    
    print("📊 Sync Analysis:")
    print(f"   To add: {len(to_add)}")
    print(f"   To deactivate: {len(to_deactivate)}")
    print(f"   To update: {len(to_update)}")
    print()
    
    # Add new corpora
    if to_add:
        print("➕ Adding new corpora:")
        for corpus_name in to_add:
            vertex_corpus = vertex_corpus_dict[corpus_name]
            try:
                # Create corpus in database
                corpus_dict = CorpusRepository.create(
                    name=corpus_name,
                    display_name=corpus_name,
                    gcs_bucket=f"gs://adk-rag-ma-{corpus_name}",
                    description=f"Synced from Vertex AI on {datetime.now().isoformat()}",
                    vertex_corpus_id=vertex_corpus['resource_name']
                )
                
                print(f"   ✅ Added: {corpus_name} (ID: {corpus_dict['id']})")
                
                # Grant access to default group (if it exists)
                try:
                    default_group = GroupRepository.get_group_by_name('default')
                    if default_group:
                        GroupRepository.grant_corpus_access(
                            group_id=default_group['id'],
                            corpus_id=corpus_dict['id'],
                            permission='read'
                        )
                        print(f"      └─ Granted 'read' access to 'default' group")
                except Exception as e:
                    print(f"      ⚠️  Could not grant default group access: {e}")
                    
            except Exception as e:
                print(f"   ❌ Failed to add {corpus_name}: {e}")
        
        print()
    
    # Deactivate removed corpora
    if to_deactivate:
        print("🔴 Deactivating removed corpora:")
        for corpus_name in to_deactivate:
            db_corpus = db_corpus_dict[corpus_name]
            if db_corpus['is_active']:
                try:
                    CorpusRepository.update(
                        corpus_id=db_corpus['id'],
                        is_active=False
                    )
                    print(f"   ✅ Deactivated: {corpus_name}")
                except Exception as e:
                    print(f"   ❌ Failed to deactivate {corpus_name}: {e}")
            else:
                print(f"   ⏭️  Already inactive: {corpus_name}")
        
        print()
    
    # Update/reactivate existing corpora
    if to_update:
        print("🔄 Updating existing corpora:")
        for corpus_name in to_update:
            db_corpus = db_corpus_dict[corpus_name]
            vertex_corpus = vertex_corpus_dict[corpus_name]
            
            updates = {}
            
            # Reactivate if inactive
            if not db_corpus['is_active']:
                updates['is_active'] = True
            
            # Update vertex_corpus_id if different
            if db_corpus['vertex_corpus_id'] != vertex_corpus['resource_name']:
                updates['vertex_corpus_id'] = vertex_corpus['resource_name']
            
            if updates:
                try:
                    CorpusRepository.update(
                        corpus_id=db_corpus['id'],
                        **updates
                    )
                    update_desc = ', '.join([f"{k}={v}" for k, v in updates.items()])
                    print(f"   ✅ Updated: {corpus_name} ({update_desc})")
                except Exception as e:
                    print(f"   ❌ Failed to update {corpus_name}: {e}")
            else:
                print(f"   ⏭️  No changes needed: {corpus_name}")
        
        print()
    
    # Final summary
    print("=" * 60)
    print("✅ Sync completed successfully!")
    print(f"   Total corpora in Vertex AI: {len(vertex_names)}")
    print(f"   Total active corpora in DB: {len([c for c in CorpusRepository.get_all(active_only=True)])}")
    print("=" * 60)
    
    return True

if __name__ == "__main__":
    success = sync_corpora()
    sys.exit(0 if success else 1)
