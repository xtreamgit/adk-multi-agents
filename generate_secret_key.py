#!/usr/bin/env python3
"""
Generate a secure SECRET_KEY for the RAG Agent application.
"""
import secrets

# Generate a cryptographically secure random key
secret_key = secrets.token_urlsafe(32)
print(f"Generated SECRET_KEY: {secret_key}")
print(f"\nTo use this key, update your .env.yaml file:")
print(f"SECRET_KEY: {secret_key}")
