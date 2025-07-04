import React, { useState } from 'react';
import { templateConfig } from '../../config/templateConfig';
import { brandConfig } from '../../config/brandConfig';

interface TemplateFiltersProps {
  selectedFilters: Record<string, string>;
  onFiltersChange: (filters: Record<string, string>) => void;
  className?: string;
}

export const TemplateFilters: React.FC<TemplateFiltersProps> = ({ 
  selectedFilters, 
  onFiltersChange, 
  className = '' 
}) => {
  const [isExpanded, setIsExpanded] = useState(false);

  const handleFilterChange = (filterKey: string, value: string) => {
    const newFilters = { ...selectedFilters };
    
    if (newFilters[filterKey] === value) {
      // Remove filter if already selected
      delete newFilters[filterKey];
    } else {
      // Set new filter value
      newFilters[filterKey] = value;
    }
    
    onFiltersChange(newFilters);
  };

  const clearAllFilters = () => {
    onFiltersChange({});
  };

  const activeFilterCount = Object.keys(selectedFilters).length;

  return (
    <div className={`template-filters ${className}`}>
      {/* 🎯 Filter toggle button */}
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full flex items-center justify-between px-4 py-3 rounded-lg font-medium transition-all duration-300"
        style={{
          background: `linear-gradient(135deg, 
            ${brandConfig.colors.elevatedBlack}90 0%, 
            ${brandConfig.colors.surfaceBlack}80 100%
          )`,
          border: `1px solid ${activeFilterCount > 0 ? brandConfig.colors.electricBlue : brandConfig.colors.neuralGray}30`,
          color: brandConfig.colors.pureWhite,
          fontFamily: brandConfig.typography.fontPrimary,
          fontSize: brandConfig.typography.fontSizeBase,
          backdropFilter: 'blur(20px)'
        }}
      >
        <div className="flex items-center space-x-2">
          <span>🎛️</span>
          <span>Filters</span>
          {activeFilterCount > 0 && (
            <span 
              className="px-2 py-1 rounded-full text-xs font-bold"
              style={{
                background: brandConfig.colors.electricBlue,
                color: brandConfig.colors.trueBlack,
                fontFamily: brandConfig.typography.fontCode
              }}
            >
              {activeFilterCount}
            </span>
          )}
        </div>
        
        <span 
          className="transition-transform duration-300"
          style={{
            transform: isExpanded ? 'rotate(180deg)' : 'rotate(0deg)'
          }}
        >
          ▼
        </span>
      </button>

      {/* 🎨 Filters panel */}
      {isExpanded && (
        <div 
          className="filters-panel mt-3 p-4 rounded-lg"
          style={{
            background: `linear-gradient(135deg, 
              ${brandConfig.colors.elevatedBlack}95 0%, 
              ${brandConfig.colors.surfaceBlack}90 100%
            )`,
            border: `1px solid ${brandConfig.colors.neuralGray}30`,
            borderRadius: brandConfig.layout.borderRadius,
            backdropFilter: 'blur(20px)'
          }}
        >
          {/* Difficulty filter */}
          <div className="filter-group mb-4">
            <h4 
              className="text-sm font-semibold mb-2"
              style={{
                fontFamily: brandConfig.typography.fontCode,
                color: brandConfig.colors.textSecondary,
                textTransform: 'uppercase',
                letterSpacing: '0.05em'
              }}
            >
              Difficulty
            </h4>
            
            <div className="flex flex-wrap gap-2">
              {templateConfig.filters.difficulty.map((option) => {
                const isSelected = selectedFilters.difficulty === option.value;
                
                return (
                  <button
                    key={option.value}
                    onClick={() => handleFilterChange('difficulty', option.value)}
                    className="px-3 py-2 rounded text-sm font-medium transition-all duration-200 hover:scale-105"
                    style={{
                      background: isSelected
                        ? `linear-gradient(135deg, ${brandConfig.colors.synapticGreen}, ${brandConfig.colors.electricBlue})`
                        : `${brandConfig.colors.neuralGray}20`,
                      color: isSelected ? brandConfig.colors.trueBlack : brandConfig.colors.textSecondary,
                      border: `1px solid ${isSelected ? brandConfig.colors.synapticGreen : brandConfig.colors.neuralGray}30`,
                      fontFamily: brandConfig.typography.fontPrimary
                    }}
                    title={option.description}
                  >
                    {option.label}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Duration filter */}
          <div className="filter-group mb-4">
            <h4 
              className="text-sm font-semibold mb-2"
              style={{
                fontFamily: brandConfig.typography.fontCode,
                color: brandConfig.colors.textSecondary,
                textTransform: 'uppercase',
                letterSpacing: '0.05em'
              }}
            >
              Duration
            </h4>
            
            <div className="flex flex-wrap gap-2">
              {templateConfig.filters.duration.map((option) => {
                const isSelected = selectedFilters.duration === option.value;
                
                return (
                  <button
                    key={option.value}
                    onClick={() => handleFilterChange('duration', option.value)}
                    className="px-3 py-2 rounded text-sm font-medium transition-all duration-200 hover:scale-105"
                    style={{
                      background: isSelected
                        ? `linear-gradient(135deg, ${brandConfig.colors.neuralPurple}, ${brandConfig.colors.neuralPink})`
                        : `${brandConfig.colors.neuralGray}20`,
                      color: isSelected ? brandConfig.colors.pureWhite : brandConfig.colors.textSecondary,
                      border: `1px solid ${isSelected ? brandConfig.colors.neuralPurple : brandConfig.colors.neuralGray}30`,
                      fontFamily: brandConfig.typography.fontPrimary
                    }}
                    title={option.description}
                  >
                    {option.label}
                  </button>
                );
              })}
            </div>
          </div>

          {/* API Requirements filter */}
          <div className="filter-group mb-4">
            <h4 
              className="text-sm font-semibold mb-2"
              style={{
                fontFamily: brandConfig.typography.fontCode,
                color: brandConfig.colors.textSecondary,
                textTransform: 'uppercase',
                letterSpacing: '0.05em'
              }}
            >
              API Requirements
            </h4>
            
            <div className="flex flex-wrap gap-2">
              {templateConfig.filters.apiRequirements.map((option) => {
                const isSelected = selectedFilters.apiRequirements === option.value;
                
                return (
                  <button
                    key={option.value}
                    onClick={() => handleFilterChange('apiRequirements', option.value)}
                    className="px-3 py-2 rounded text-sm font-medium transition-all duration-200 hover:scale-105"
                    style={{
                      background: isSelected
                        ? `linear-gradient(135deg, ${brandConfig.colors.electricBlue}, ${brandConfig.colors.quantumTeal})`
                        : `${brandConfig.colors.neuralGray}20`,
                      color: isSelected ? brandConfig.colors.trueBlack : brandConfig.colors.textSecondary,
                      border: `1px solid ${isSelected ? brandConfig.colors.electricBlue : brandConfig.colors.neuralGray}30`,
                      fontFamily: brandConfig.typography.fontPrimary
                    }}
                    title={option.description}
                  >
                    {option.label}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Clear all filters */}
          {activeFilterCount > 0 && (
            <div className="filter-actions pt-3 border-t" style={{ borderColor: `${brandConfig.colors.neuralGray}30` }}>
              <button
                onClick={clearAllFilters}
                className="w-full px-4 py-2 rounded text-sm font-medium transition-all duration-200 hover:scale-105"
                style={{
                  background: `${brandConfig.colors.criticalRed}20`,
                  color: brandConfig.colors.criticalRed,
                  border: `1px solid ${brandConfig.colors.criticalRed}30`,
                  fontFamily: brandConfig.typography.fontPrimary
                }}
              >
                🗑️ Clear All Filters
              </button>
            </div>
          )}

          {/* Neural pulse indicator */}
          <div className="mt-3 flex items-center justify-center space-x-2 opacity-60">
            <div 
              className="w-1 h-1 rounded-full animate-pulse"
              style={{ background: brandConfig.colors.electricBlue }}
            />
            <span 
              className="text-xs font-mono"
              style={{
                fontFamily: brandConfig.typography.fontCode,
                color: brandConfig.colors.textMuted
              }}
            >
              FILTER SYNC ACTIVE
            </span>
            <div 
              className="w-1 h-1 rounded-full animate-pulse"
              style={{ 
                background: brandConfig.colors.neuralPurple,
                animationDelay: '0.5s'
              }}
            />
          </div>
        </div>
      )}
    </div>
  );
}; 