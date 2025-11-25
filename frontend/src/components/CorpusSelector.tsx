"use client";

import { useState, useEffect } from 'react';
import { apiClient } from '../lib/api';

interface CorpusSelectorProps {
  selectedCorpus: string | null;
  onCorpusSelect: (corpus: string | null) => void;
}

export default function CorpusSelector({ selectedCorpus, onCorpusSelect }: CorpusSelectorProps) {
  const [corpora, setCorpora] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadCorpora = async () => {
      try {
        setLoading(true);
        const response = await apiClient.listCorpora();
        
        // Parse the response text to extract corpus names
        const corpusNames = parseCorpusResponse(response);
        
        // Sort corpora alphabetically
        const sortedCorpora = corpusNames.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
        setCorpora(sortedCorpora);
        
        // Set default selection to first corpus if none selected
        if (!selectedCorpus && sortedCorpora.length > 0) {
          onCorpusSelect(sortedCorpora[0]);
        }
      } catch (err) {
        console.error('Failed to load corpora:', err);
        setError(err instanceof Error ? err.message : 'Failed to load corpora');
      } finally {
        setLoading(false);
      }
    };

    loadCorpora();
  }, [selectedCorpus, onCorpusSelect]);

  const parseCorpusResponse = (response: string): string[] => {
    // Extract corpus names from the response text
    // Expected format includes bold formatting: "**security** (resource_name: `...`), **ai** (resource_name: `...`)"
    const corpusNames: string[] = [];
    
    // Look for bold corpus names in the format **corpus_name**
    const boldMatches = response.match(/\*\*([^*]+)\*\*/g);
    if (boldMatches) {
      for (const match of boldMatches) {
        const corpusName = match.replace(/\*\*/g, '').trim();
        if (corpusName && !corpusName.toLowerCase().includes('corpus')) {
          corpusNames.push(corpusName);
        }
      }
    }
    
    // Fallback: Look for lines that start with "* " (bullet points) for simpler format
    if (corpusNames.length === 0) {
      const lines = response.split('\n');
      for (const line of lines) {
        const match = line.match(/^\s*\*\s+(.+)$/);
        if (match && match[1]) {
          const corpusName = match[1].trim();
          if (corpusName && !corpusName.toLowerCase().includes('corpus')) {
            corpusNames.push(corpusName);
          }
        }
      }
    }
    
    return [...new Set(corpusNames)]; // Remove duplicates
  };

  if (loading) {
    return (
      <div className="w-full">
        <div className="animate-pulse">
          <div className="h-4 bg-gray-200 rounded mb-2"></div>
          <div className="h-8 bg-gray-200 rounded"></div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="w-full">
        <div className="text-red-600">
          <h3 className="text-sm font-medium mb-1">Error Loading Corpora</h3>
          <p className="text-xs">{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="w-full">
      <div className="mb-4">
        <h3 className="text-sm font-medium text-gray-700 mb-2">
          Available Corpora
        </h3>
      </div>

      <div className="space-y-2">
        <select
          id="corpus-select"
          value={selectedCorpus || ''}
          onChange={(e) => onCorpusSelect(e.target.value || null)}
          className="w-full p-2 text-sm border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent bg-white"
        >
          <option value="">Select a corpus...</option>
          {corpora.map((corpus) => (
            <option key={corpus} value={corpus}>
              {corpus}
            </option>
          ))}
        </select>

        {selectedCorpus && (
          <div className="p-2 bg-green-50 border border-green-200 rounded-lg">
            <p className="text-xs text-green-700">
              Selected: <span className="font-medium">{selectedCorpus}</span>
            </p>
          </div>
        )}

        {!loading && corpora.length === 0 && (
          <div className="p-2 bg-yellow-50 border border-yellow-200 rounded-lg">
            <p className="text-xs text-yellow-700">
              No corpora found. You may need to create one first.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
