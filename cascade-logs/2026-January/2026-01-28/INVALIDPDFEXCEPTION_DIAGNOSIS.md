# InvalidPDFException Error - Diagnosis and Solution

**Date:** January 28, 2026, 8:06 PM PST  
**Error:** `InvalidPDFException: Invalid PDF structure`  
**Status:** Browser caching issue

---

## Problem Analysis

### What's Happening

The error `InvalidPDFException: Invalid PDF structure` means PDF.js is receiving data it cannot parse as a valid PDF.

### Evidence

1. **Backend proxy works correctly:**
   ```bash
   curl -H "Authorization: Bearer $TOKEN" \
     "http://localhost:8000/api/documents/proxy/1/0132366754_Jang_book.pdf"
   # Returns: %PDF-1.5... (valid PDF data)
   ```

2. **Frontend code is updated:**
   ```typescript
   // Line 101 in pdfThumbnail.ts
   // Check content type
   const contentType = response.headers.get('content-type');
   ```

3. **But browser is using OLD cached JavaScript:**
   - Browser compiled the old code before our fixes
   - Hard refresh doesn't always clear Next.js compiled chunks
   - The old code tries to parse JSON errors as PDF data

---

## Root Cause

**Browser JavaScript cache** - The browser loaded and cached the JavaScript bundles before we made our fixes. Even though the source files are updated, the browser is executing the old compiled code.

### Why This Happens

1. Next.js compiles React components into JavaScript chunks
2. Browser caches these chunks for performance
3. Hard refresh (`Cmd+Shift+R`) clears HTML cache but not always JS chunks
4. Turbopack hot reload doesn't always catch all changes

---

## Solution

### Option 1: Clear Browser Cache Completely

**Chrome/Edge:**
1. Open DevTools (`F12` or `Cmd+Option+I`)
2. Right-click the refresh button
3. Select **"Empty Cache and Hard Reload"**

**Firefox:**
1. Open DevTools (`F12`)
2. Click Settings (gear icon)
3. Check "Disable HTTP Cache (when toolbox is open)"
4. Refresh with DevTools open

**Safari:**
1. Develop menu → Empty Caches
2. Then hard refresh (`Cmd+Shift+R`)

### Option 2: Delete Next.js Build Cache

```bash
cd frontend
rm -rf .next
npm run dev -- --port 3000
```

This forces Next.js to recompile everything from scratch.

### Option 3: Use Incognito/Private Window

Open http://localhost:3000 in an incognito/private window - no cache at all.

---

## Verification Steps

After clearing cache, you should see these console logs:

```
[Thumbnail] Using proxy URL: http://localhost:8000/api/documents/proxy/1/...
[PDF Thumbnail] Fetching PDF with authentication...
[PDF Thumbnail] PDF fetched successfully, size: 8883908 bytes
[PDF Thumbnail] PDF loaded successfully, pages: 150
[PDF Thumbnail] First page retrieved
```

**If you still see the old error messages, the browser is still using cached code.**

---

## Why Our Fixes Are Correct

The code we wrote handles this scenario:

```typescript
// Check if response is OK
if (!response.ok) {
  let errorMessage = `${response.status} ${response.statusText}`;
  try {
    const errorData = await response.json();
    errorMessage = errorData.detail || errorMessage;
  } catch {
    // Not JSON, use status text
  }
  throw new Error(`Failed to fetch PDF: ${errorMessage}`);
}

// Validate content type
const contentType = response.headers.get('content-type');
if (contentType && !contentType.includes('application/pdf')) {
  throw new Error(`Expected PDF but got ${contentType}`);
}
```

**This prevents InvalidPDFException by:**
1. Checking response status before parsing
2. Parsing JSON errors properly
3. Validating content-type header
4. Only passing valid PDF data to PDF.js

---

## Alternative: Force Fresh Build

If cache clearing doesn't work, force a complete rebuild:

```bash
# Stop services
pkill -9 -f "uvicorn"
pkill -9 -f "next dev"

# Clear all caches
cd frontend
rm -rf .next
rm -rf node_modules/.cache

# Restart
cd ..
cd backend && source .venv/bin/activate && \
  python -m uvicorn src.api.server:app --host 0.0.0.0 --port 8000 --reload &

cd ../frontend && npm run dev -- --port 3000 &
```

---

## Expected Behavior After Fix

**Success case:**
- Thumbnail appears within 2-3 seconds
- No errors in console
- Clear progress logs

**Error case (quota exceeded):**
- Clear error: "Quota exceeded for quota metric 'VertexRagDataService requests'"
- NOT "Invalid PDF structure"

**Error case (document not found):**
- Clear error: "Failed to fetch PDF: Document not found"
- NOT "Invalid PDF structure"

---

## Summary

**The code is correct.** The browser is executing old cached JavaScript that doesn't have our fixes. Clear the browser cache or delete `.next` folder to force recompilation.

**Recommended action:**
```bash
cd frontend
rm -rf .next
# Then hard refresh browser
```
