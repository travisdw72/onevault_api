import React, { useState } from 'react';
import { templateConfig } from '../../config/templateConfig';
import { brandConfig } from '../../config/brandConfig';

interface TemplateSearchProps {
  searchQuery: string;
  onSearchChange: (query: string) => void;
  className?: string;
}

export const TemplateSearch: React.FC<TemplateSearchProps> = ({ 
  searchQuery, 
  onSearchChange, 
  className = '' 
}) => {
  const [isFocused, setIsFocused] = useState(false);

  const handleSearchChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    onSearchChange(event.target.value);
  };

  const handleClearSearch = () => {
    onSearchChange('');
  };

  return (
    <div className={`template-search ${className}`}>
      <div 
        className="search-input-container"
        style={{
          position: 'relative',
          background: `linear-gradient(135deg, 
            ${brandConfig.colors.elevatedBlack}90 0%, 
            ${brandConfig.colors.surfaceBlack}80 100%
          )`,
          border: `1px solid ${isFocused ? brandConfig.colors.synapticGreen : brandConfig.colors.neuralGray}30`,
          borderRadius: brandConfig.layout.borderRadius,
          padding: brandConfig.spacing.md,
          transition: `all ${brandConfig.animations.durationNormal}`,
          backdropFilter: 'blur(20px)'
        }}
      >
        {/* 🔍 Search icon */}
        <div 
          className="absolute left-3 top-1/2 transform -translate-y-1/2"
          style={{
            color: isFocused ? brandConfig.colors.synapticGreen : brandConfig.colors.textMuted,
            transition: `color ${brandConfig.animations.durationNormal}`
          }}
        >
          🔍
        </div>

        {/* Search input */}
        <input
          type="text"
          value={searchQuery}
          onChange={handleSearchChange}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          placeholder={templateConfig.gallery.searchPlaceholder}
          className="w-full bg-transparent outline-none"
          style={{
            paddingLeft: brandConfig.spacing.xl,
            paddingRight: searchQuery ? brandConfig.spacing.xl : brandConfig.spacing.sm,
            color: brandConfig.colors.pureWhite,
            fontFamily: brandConfig.typography.fontPrimary,
            fontSize: brandConfig.typography.fontSizeBase
          }}
        />

        {/* 🗑️ Clear button */}
        {searchQuery && (
          <button
            onClick={handleClearSearch}
            className="absolute right-3 top-1/2 transform -translate-y-1/2 w-5 h-5 rounded-full flex items-center justify-center transition-all duration-200 hover:scale-110"
            style={{
              background: `${brandConfig.colors.neuralGray}40`,
              color: brandConfig.colors.textSecondary,
              border: 'none',
              fontSize: brandConfig.typography.fontSizeXs
            }}
          >
            ×
          </button>
        )}

        {/* Neural glow effect when focused */}
        <div 
          className="absolute inset-0 pointer-events-none rounded transition-opacity duration-300"
          style={{
            background: `radial-gradient(circle at center, ${brandConfig.colors.synapticGreen}10 0%, transparent 70%)`,
            opacity: isFocused ? 1 : 0
          }}
        />
      </div>

      {/* Search suggestions/hints */}
      {isFocused && !searchQuery && (
        <div 
          className="search-hints mt-2 p-3 rounded"
          style={{
            background: `${brandConfig.colors.elevatedBlack}80`,
            border: `1px solid ${brandConfig.colors.neuralGray}20`,
            borderRadius: brandConfig.layout.borderRadius,
            backdropFilter: 'blur(20px)'
          }}
        >
          <div className="flex flex-wrap gap-2">
            {['veterinary', 'health-monitoring', 'computer-vision', 'pattern-analysis'].map((hint) => (
              <button
                key={hint}
                onClick={() => onSearchChange(hint)}
                className="px-2 py-1 rounded text-xs transition-all duration-200 hover:scale-105"
                style={{
                  background: `${brandConfig.colors.synapticGreen}20`,
                  color: brandConfig.colors.synapticGreen,
                  border: `1px solid ${brandConfig.colors.synapticGreen}30`,
                  fontFamily: brandConfig.typography.fontCode
                }}
              >
                {hint}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}; 