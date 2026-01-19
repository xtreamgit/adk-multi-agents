"use client";

import DocumentRetrievalPanel from '@/components/DocumentRetrievalPanel';

export default function TestDocumentsPage() {
  return (
    <div className="min-h-screen bg-gray-100 py-8">
      <div className="max-w-4xl mx-auto px-4">
        <h1 className="text-3xl font-bold text-gray-900 mb-6">
          Document Retrieval Test
        </h1>
        <DocumentRetrievalPanel defaultCorpusId={1} />
      </div>
    </div>
  );
}
