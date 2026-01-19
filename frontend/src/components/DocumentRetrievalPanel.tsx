"use client";

import { useState } from 'react';
import { useDocumentRetrieval } from '../hooks/useDocumentRetrieval';
import DocumentViewer from './DocumentViewer';

interface DocumentRetrievalPanelProps {
  defaultCorpusId?: number;
}

export default function DocumentRetrievalPanel({ defaultCorpusId = 1 }: DocumentRetrievalPanelProps) {
  const [corpusId, setCorpusId] = useState(defaultCorpusId.toString());
  const [documentName, setDocumentName] = useState('');
  const { retrieveDocument, closeDocument, currentDocument, isRetrieving, error } = useDocumentRetrieval();

  const handleRetrieve = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!documentName.trim() || !corpusId) return;

    try {
      await retrieveDocument(parseInt(corpusId), documentName, true);
    } catch (err) {
      console.error('Failed to retrieve document:', err);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow p-6 max-w-2xl mx-auto">
      <h2 className="text-2xl font-bold text-gray-900 mb-4">Document Retrieval Test</h2>
      
      <form onSubmit={handleRetrieve} className="space-y-4">
        <div>
          <label htmlFor="corpusId" className="block text-sm font-medium text-gray-700 mb-2">
            Corpus ID
          </label>
          <input
            type="number"
            id="corpusId"
            value={corpusId}
            onChange={(e) => setCorpusId(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="1"
            required
          />
          <p className="mt-1 text-xs text-gray-500">Enter the corpus ID (e.g., 1 for ai-books)</p>
        </div>

        <div>
          <label htmlFor="documentName" className="block text-sm font-medium text-gray-700 mb-2">
            Document Name
          </label>
          <input
            type="text"
            id="documentName"
            value={documentName}
            onChange={(e) => setDocumentName(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="e.g., Hands-On Large Language Models.pdf"
            required
          />
          <p className="mt-1 text-xs text-gray-500">Enter the exact document name including extension</p>
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-md p-3">
            <p className="text-sm text-red-600">
              <strong>Error:</strong> {error}
            </p>
          </div>
        )}

        <button
          type="submit"
          disabled={isRetrieving || !documentName.trim()}
          className="w-full px-4 py-2 bg-blue-600 text-white font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isRetrieving ? 'Retrieving...' : 'Retrieve Document'}
        </button>
      </form>

      <div className="mt-6 bg-blue-50 border border-blue-200 rounded-md p-4">
        <h3 className="text-sm font-medium text-blue-900 mb-2">How to use:</h3>
        <ol className="text-sm text-blue-700 space-y-1 list-decimal list-inside">
          <li>Enter the corpus ID (numeric ID from database)</li>
          <li>Enter the exact document name as stored in Vertex AI</li>
          <li>Click "Retrieve Document" to view it</li>
          <li>PDF files will preview in-browser, others will show download option</li>
        </ol>
      </div>

      {currentDocument && (
        <DocumentViewer
          document={currentDocument}
          onClose={closeDocument}
        />
      )}
    </div>
  );
}
