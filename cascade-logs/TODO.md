# TODO List

## Purpose

This file tracks features, fixes, and tasks that need to be completed either the same day or in the future. Items are added throughout the day as they are identified and removed/checked off as they are completed.

**Usage:**
- Add new items to the bottom of the list with a checkbox `- [ ]`
- Mark completed items with `- [x]`
- Include date when adding items for context
- Prioritize with labels: `[HIGH]`, `[MEDIUM]`, `[LOW]`

---

## Active Tasks

### Today (January 8, 2026)

- [x] Fix 429 RESOURCE_EXHAUSTED rate limit error
- [x] Implement exponential backoff retry logic
- [x] Fix agent loading architecture (JSON-based configs)
- [x] Create Corpora Nuance.md documentation
- [x] Corpus Selector Persistence - Phase 3: Visibility & Vertex AI Sync
- [x] Corpus Selector Persistence - Phase 4: Auto-save functionality
- [x] Corpus Selector Persistence - Phase 5: Load preferences on login
- [x] Show all corpora with access indicators (lock icons for restricted)
- [x] Create comprehensive testing guide for corpus selector feature

---

## Upcoming Tasks

### High Priority
- [ ] Test multi-corpus query with real user queries
- [ ] Clean up debug logging from yesterday's session
- [ ] Verify all 5 corpora are accessible in UI

### Medium Priority
- [ ] Enhance sync script to auto-grant group permissions
- [ ] Add query performance metrics
- [ ] Update session summary with today's work

### Low Priority
- [ ] Rate limit prediction/throttling feature
- [ ] Corpus query result caching
- [ ] User-configurable retry settings

---

## Future Enhancements

- [ ] Corpus health monitoring dashboard
- [ ] Automated testing for multi-corpus queries
- [ ] Documentation for corpus creation best practices
- [ ] Performance benchmarking tools


- [ ] Add the metadata to the corpus when it is created. The metadata should include the group name (owners), the type of data, date created and author, and purpose. This could be a dialog box accessed from the "Data" or "Corpus" definition menu option. This will help creating reports and better analysis of the data.

- [ ] Test the corpus selection to ensure only the selected corpora is used during the session.

- [ ] Need to find a way to ensure that the users only create corpora against a "folder" that has no subfolders. If we don't, we will have the issue where the fiction corpus was a subfolder of the usfs-corpora which got deleted by one of the users. This means that any queries from fiction will fail.

---

**Last Updated:** January 8, 2026 - 12:40 PM

Create a list of what we are going to call "Corpora Actions". These actions are designed to include any kind of data manipulation or change to the corpora data used during the session. The Corpora Actions (CA)could be downloading the document that they are currently using by typing "download" or "save". Another CA could be creating a document editing UI to allow users to edit the document they are currently using. The editor CA could also allow the users to edit the metadata of the document. 


Create a graceful way to handle the Vertex AI errors. Sometimes I get this error: Error
API request failed: {"detail":"Error processing request: 429 RESOURCE_EXHAUSTED. {'error': {'code': 429, 'message': 'Resource exhausted. Please try again later. Please refer to https://cloud.google.com/vertex-ai/generative-ai/docs/error-code-429 for more details.', 'status': 'RESOURCE_EXHAUSTED'}}"}. We need to handle this error gracefully and provide a better user experience.