import { useState } from 'react';
import { apiClient, DocumentRetrievalResponse } from '../lib/api';

export function useDocumentRetrieval() {
  const [isRetrieving, setIsRetrieving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentDocument, setCurrentDocument] = useState<DocumentRetrievalResponse | null>(null);

  const retrieveDocument = async (corpusId: number, documentName: string, generateSignedUrl: boolean = true) => {
    setIsRetrieving(true);
    setError(null);
    
    try {
      const document = await apiClient.retrieveDocument(corpusId, documentName, generateSignedUrl);
      setCurrentDocument(document);
      return document;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to retrieve document';
      setError(errorMessage);
      throw err;
    } finally {
      setIsRetrieving(false);
    }
  };

  const closeDocument = () => {
    setCurrentDocument(null);
    setError(null);
  };

  return {
    retrieveDocument,
    closeDocument,
    isRetrieving,
    error,
    currentDocument,
  };
}
