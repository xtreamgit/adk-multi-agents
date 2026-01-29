/**
 * PDF Thumbnail Generation Utility
 * Generates thumbnail images from PDF documents using pdf.js
 * 
 * NOTE: This module should only be used on the client side
 */

// Dynamic import to avoid SSR issues
let pdfjsLib: typeof import('pdfjs-dist') | null = null;

// Initialize PDF.js only in browser environment
if (typeof window !== 'undefined') {
  import('pdfjs-dist').then((pdfjs) => {
    pdfjsLib = pdfjs;
    // Use unpkg CDN as fallback (more reliable than cdnjs)
    pdfjsLib.GlobalWorkerOptions.workerSrc = `https://unpkg.com/pdfjs-dist@${pdfjs.version}/build/pdf.worker.min.mjs`;
  });
}

interface ThumbnailOptions {
  maxWidth?: number;
  maxHeight?: number;
  scale?: number;
}

/**
 * Generate a thumbnail from a PDF URL
 * @param url - The URL of the PDF document
 * @param options - Thumbnail generation options
 * @returns Promise resolving to a base64 data URL of the thumbnail image
 */
export async function generatePdfThumbnail(
  url: string,
  options: ThumbnailOptions = {}
): Promise<string> {
  // Ensure we're in browser environment
  if (typeof window === 'undefined') {
    throw new Error('generatePdfThumbnail can only be called in browser environment');
  }

  // Ensure pdfjs is loaded
  if (!pdfjsLib) {
    pdfjsLib = await import('pdfjs-dist');
    // Use unpkg CDN as fallback (more reliable than cdnjs)
    pdfjsLib.GlobalWorkerOptions.workerSrc = `https://unpkg.com/pdfjs-dist@${pdfjsLib.version}/build/pdf.worker.min.mjs`;
  }

  const {
    maxWidth = 280,
    maxHeight = 380,
    scale = 1.5
  } = options;

  try {
    // Load the PDF document
    console.log('[PDF Thumbnail] Loading PDF from URL:', url.substring(0, 100) + '...');
    const loadingTask = pdfjsLib.getDocument({
      url,
      withCredentials: false,
      isEvalSupported: false,
    });
    const pdf = await loadingTask.promise;
    console.log('[PDF Thumbnail] PDF loaded successfully, pages:', pdf.numPages);

    // Get the first page
    const page = await pdf.getPage(1);
    console.log('[PDF Thumbnail] First page retrieved');

    // Calculate viewport
    const viewport = page.getViewport({ scale });

    // Create canvas
    const canvas = document.createElement('canvas');
    const context = canvas.getContext('2d');

    if (!context) {
      throw new Error('Could not get canvas context');
    }

    // Calculate dimensions to fit within max bounds while preserving aspect ratio
    let width = viewport.width;
    let height = viewport.height;

    if (width > maxWidth) {
      height = (height * maxWidth) / width;
      width = maxWidth;
    }

    if (height > maxHeight) {
      width = (width * maxHeight) / height;
      height = maxHeight;
    }

    canvas.width = width;
    canvas.height = height;

    // Render PDF page to canvas
    const renderViewport = page.getViewport({ scale: width / viewport.width });
    const renderContext = {
      canvasContext: context,
      viewport: renderViewport,
      canvas: canvas
    };

    await page.render(renderContext).promise;

    // Convert canvas to data URL
    const dataUrl = canvas.toDataURL('image/png', 0.8);

    // Cleanup
    pdf.destroy();

    return dataUrl;
  } catch (error) {
    console.error('[PDF Thumbnail] Error generating PDF thumbnail:', error);
    console.error('[PDF Thumbnail] Error type:', error instanceof Error ? error.constructor.name : typeof error);
    console.error('[PDF Thumbnail] Error message:', error instanceof Error ? error.message : String(error));
    console.error('[PDF Thumbnail] Error stack:', error instanceof Error ? error.stack : 'No stack trace');
    
    // Re-throw with more context
    if (error instanceof Error) {
      throw new Error(`Failed to generate PDF thumbnail: ${error.message}`);
    }
    throw new Error('Failed to generate PDF thumbnail: Unknown error');
  }
}

/**
 * Generate thumbnail with caching
 */
export class ThumbnailCache {
  private cache: Map<string, string> = new Map();

  async getThumbnail(url: string, options?: ThumbnailOptions): Promise<string> {
    const cacheKey = `${url}-${JSON.stringify(options)}`;
    
    if (this.cache.has(cacheKey)) {
      return this.cache.get(cacheKey)!;
    }

    const thumbnail = await generatePdfThumbnail(url, options);
    this.cache.set(cacheKey, thumbnail);
    
    return thumbnail;
  }

  clear(): void {
    this.cache.clear();
  }

  remove(url: string): void {
    // Remove all entries for this URL regardless of options
    const keysToDelete: string[] = [];
    this.cache.forEach((_, key) => {
      if (key.startsWith(url)) {
        keysToDelete.push(key);
      }
    });
    keysToDelete.forEach(key => this.cache.delete(key));
  }
}
