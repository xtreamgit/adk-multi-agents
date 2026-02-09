# Corpora Nuance

**Date:** January 8, 2026  
**Session:** Multi-Corpus Query Enhancement

---

## Overview

This document captures important nuances and considerations when working with multiple Vertex AI RAG corpora in the adk-multi-agents system.

---

## Key Learnings

The corpora documents should be in English. When creating the corpus, ensure that the files are not in parent folder. Prefferably, the files should be in a subfolder. The LLM cannot handle well the corpora documents that are in parent folder.

Recommendation: Always create corpora with the name of the folder where the files are located.






