"use client";

import { useState, useEffect } from 'react';
import { apiClient } from '@/lib/api-enhanced';
import { useDocumentRetrieval } from '@/hooks/useDocumentRetrieval';
import { generatePdfThumbnailWithRetry } from '@/lib/pdfThumbnail';
import CorpusSidebar from './CorpusSidebar';
import DocumentListPanel from './DocumentListPanel';
import DocumentPreview from './DocumentPreview';
import DocumentViewer from '../DocumentViewer';

interface Corpus {
  id: number;
  name: string;
  display_name: string;
}

interface Document {
  file_id: string;
  display_name: string;
  file_type: string;
  created_at?: string;
  size_bytes?: number;
}

export default function EmeraldRetriever() {
  // State for corpora
  const [corpora, setCorpora] = useState<Corpus[]>([]);
  const [loadingCorpora, setLoadingCorpora] = useState(true);
  const [selectedCorpusId, setSelectedCorpusId] = useState<number | null>(null);
  
  // State for documents
  const [documents, setDocuments] = useState<Document[]>([]);
  const [loadingDocuments, setLoadingDocuments] = useState(false);
  const [selectedDocument, setSelectedDocument] = useState<Document | null>(null);
  
  // State for thumbnail
  const [thumbnailUrl, setThumbnailUrl] = useState<string | null>(null);
  const [generatingThumbnail, setGeneratingThumbnail] = useState(false);
  
  // Document retrieval hook
  const { retrieveDocument, closeDocument, currentDocument } = useDocumentRetrieval();

  // Load corpora on mount
  useEffect(() => {
    loadCorpora();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Load documents when corpus changes
  useEffect(() => {
    if (selectedCorpusId) {
      loadDocuments(selectedCorpusId);
    }
  }, [selectedCorpusId]);

  // Generate thumbnail when document is selected
  useEffect(() => {
    if (selectedDocument) {
      generateThumbnail(selectedDocument);
    } else {
      setThumbnailUrl(null);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedDocument]);

  const loadCorpora = async () => {
    try {
      setLoadingCorpora(true);
      const data = await apiClient.getAllCorporaWithAccess();
      setCorpora(data);
      
      // Auto-select first corpus if available
      if (data.length > 0 && !selectedCorpusId) {
        setSelectedCorpusId(data[0].id);
      }
    } catch (error) {
      console.error('Failed to load corpora:', error);
    } finally {
      setLoadingCorpora(false);
    }
  };

  const loadDocuments = async (corpusId: number) => {
    try {
      setLoadingDocuments(true);
      setDocuments([]);
      setSelectedDocument(null);
      
      const response = await apiClient.listCorpusDocuments(corpusId);
      setDocuments(response.documents || []);
    } catch (error) {
      console.error('Failed to load documents:', error);
      setDocuments([]);
    } finally {
      setLoadingDocuments(false);
    }
  };

  const generateThumbnail = async (document: Document) => {
    // Only generate thumbnails for PDFs
    if (document.file_type.toLowerCase() !== 'pdf') {
      setThumbnailUrl(null);
      setGeneratingThumbnail(false);
      return;
    }

    try {
      setGeneratingThumbnail(true);
      setThumbnailUrl(null);
      
      // Retrieve document with signed URL
      const response = await retrieveDocument(
        selectedCorpusId!,
        document.display_name,
        true
      );

      // Use backend proxy endpoint to avoid CORS issues with GCS signed URLs
      const proxyUrl = `${process.env.NEXT_PUBLIC_BACKEND_URL || 'http://localhost:8000'}/api/documents/proxy/${selectedCorpusId}/${encodeURIComponent(document.display_name)}`;
      
      console.log('[Thumbnail] Using proxy URL:', proxyUrl);
      
      // Get auth token from localStorage
      const token = localStorage.getItem('access_token');
      
      // Generate thumbnail from proxied PDF with retry logic
      const thumbnail = await generatePdfThumbnailWithRetry(proxyUrl, {
        maxWidth: 260,
        maxHeight: 360,
        headers: token ? { 'Authorization': `Bearer ${token}` } : undefined
      }, 2); // Max 2 retries
      setThumbnailUrl(thumbnail);
    } catch (error) {
      console.error('Failed to generate thumbnail:', error);
      console.error('Error details:', error instanceof Error ? error.message : error);
      setThumbnailUrl(null);
    } finally {
      setGeneratingThumbnail(false);
    }
  };

  const handleSelectCorpus = (corpusId: number) => {
    setSelectedCorpusId(corpusId);
    setSelectedDocument(null);
  };

  const handleSelectDocument = (document: Document) => {
    setSelectedDocument(document);
  };

  const handleOpenDocument = async () => {
    if (!selectedDocument || !selectedCorpusId) return;

    try {
      await retrieveDocument(
        selectedCorpusId,
        selectedDocument.display_name,
        true
      );
    } catch (error) {
      console.error('Failed to open document:', error);
    }
  };

  const handleDownload = async () => {
    if (!selectedDocument || !selectedCorpusId) return;

    try {
      const response = await retrieveDocument(
        selectedCorpusId,
        selectedDocument.display_name,
        true
      );

      if (response.access?.url) {
        // Trigger download
        const link = document.createElement('a');
        link.href = response.access.url;
        link.download = selectedDocument.display_name;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      }
    } catch (error) {
      console.error('Failed to download document:', error);
    }
  };

  const selectedCorpusName = corpora.find(c => c.id === selectedCorpusId)?.display_name || 
                            corpora.find(c => c.id === selectedCorpusId)?.name || 
                            'Unknown';

  return (
    <>
      <div className="h-screen flex flex-col bg-white">
        {/* Header */}
        <div className="border-b border-gray-200 px-6 py-4 bg-white shadow-sm">
          <h1 className="text-xl font-bold text-gray-900">Document Browser</h1>
        </div>

        {/* Three-column layout */}
        <div className="flex-1 flex overflow-hidden">
          {/* Left: Corpus Sidebar */}
          <CorpusSidebar
            corpora={corpora}
            selectedCorpusId={selectedCorpusId}
            onSelectCorpus={handleSelectCorpus}
            loading={loadingCorpora}
          />

          {/* Middle: Document List */}
          <DocumentListPanel
            corpusName={selectedCorpusName}
            documents={documents}
            selectedDocumentId={selectedDocument?.file_id || null}
            onSelectDocument={handleSelectDocument}
            loading={loadingDocuments}
          />

          {/* Right: Document Preview */}
          <DocumentPreview
            document={selectedDocument}
            thumbnailUrl={thumbnailUrl}
            generatingThumbnail={generatingThumbnail}
            onOpenDocument={handleOpenDocument}
            onDownload={handleDownload}
          />
        </div>
      </div>

      {/* Document Viewer Modal */}
      {currentDocument && (
        <DocumentViewer
          document={currentDocument}
          onClose={closeDocument}
        />
      )}
    </>
  );
}
