import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import { templateConfig } from '../../config/templateConfig';
import { brandConfig } from '../../config/brandConfig';
import { TemplateCard } from './TemplateCard';
import { TemplateFilters } from './TemplateFilters';
import { TemplateSearch } from './TemplateSearch';

interface TemplateGalleryProps {
  className?: string;
}

export const TemplateGallery: React.FC<TemplateGalleryProps> = ({ className = '' }) => {
  const { user, canAccess } = useAuth();
  const navigate = useNavigate();
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [selectedFilters, setSelectedFilters] = useState<Record<string, string>>({});
  const [searchQuery, setSearchQuery] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  // 🚀 Initialize gallery
  useEffect(() => {
    const initializeGallery = async () => {
      // Simulate neural network initialization
      await new Promise(resolve => setTimeout(resolve, 800));
      setIsLoading(false);
    };

    initializeGallery();
  }, []);

  // 🎯 Filter templates based on category, filters, and search
  const filteredTemplates = templateConfig.templates.filter(template => {
    // Category filter
    if (selectedCategory !== 'all' && template.category !== selectedCategory) {
      return false;
    }

    // Search filter
    if (searchQuery && !template.name.toLowerCase().includes(searchQuery.toLowerCase()) &&
        !template.shortDescription.toLowerCase().includes(searchQuery.toLowerCase()) &&
        !template.tags.some(tag => tag.toLowerCase().includes(searchQuery.toLowerCase()))) {
      return false;
    }

    // Additional filters
    if (selectedFilters.difficulty && template.difficulty !== selectedFilters.difficulty) {
      return false;
    }

    return true;
  });

  // 🚀 Handle template selection and navigation
  const handleTemplateSelect = (templateId: string) => {
    // Map template IDs to their specific workflow routes
    const templateRoutes: Record<string, string> = {
      'horse_health_analyzer': '/workflows/horse-health',
      // Add more template mappings as needed
    };

    const workflowRoute = templateRoutes[templateId];
    if (workflowRoute) {
      navigate(workflowRoute);
    } else {
      // Fallback for templates without specific workflows
      console.warn(`No workflow route defined for template: ${templateId}`);
      navigate(`/templates/${templateId}`);
    }
  };

  // 🎨 Loading state
  if (isLoading) {
    return (
      <div 
        className="template-gallery-loading"
        style={{
          background: `linear-gradient(135deg, 
            ${brandConfig.colors.elevatedBlack}95 0%, 
            ${brandConfig.colors.surfaceBlack}90 100%
          )`,
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexDirection: 'column',
          gap: brandConfig.spacing.lg
        }}
      >
        {/* Neural loading animation */}
        <div className="flex space-x-2">
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              className="w-3 h-3 rounded-full"
              style={{
                background: brandConfig.colors.synapticGreen,
                animation: `neural-pulse 1.5s ease-in-out infinite`,
                animationDelay: `${i * 0.2}s`
              }}
            />
          ))}
        </div>
        <p 
          className="text-lg"
          style={{
            fontFamily: brandConfig.typography.fontPrimary,
            color: brandConfig.colors.textSecondary
          }}
        >
          {templateConfig.gallery.loadingMessage}
        </p>
      </div>
    );
  }

  return (
    <div 
      className={`template-gallery min-h-screen relative overflow-x-hidden ${className}`}
      style={{ 
        background: `radial-gradient(ellipse at top, ${brandConfig.colors.neuralPurple}10 0%, ${brandConfig.colors.trueBlack} 70%)`,
        fontFamily: brandConfig.typography.fontPrimary
      }}
    >
      {/* Neural background grid */}
      <div 
        className="absolute inset-0 opacity-5"
        style={{
          backgroundImage: `
            linear-gradient(${brandConfig.colors.synapticGreen}20 1px, transparent 1px),
            linear-gradient(90deg, ${brandConfig.colors.synapticGreen}20 1px, transparent 1px)
          `,
          backgroundSize: '60px 60px'
        }}
      />

      {/* Main gallery content */}
      <div className="relative z-10">
        {/* Header navigation */}
        <nav 
          className="sticky top-0 z-40 border-b backdrop-blur-lg"
          style={{ 
            borderColor: `${brandConfig.colors.synapticGreen}20`,
            background: `${brandConfig.colors.trueBlack}90`
          }}
        >
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex items-center justify-between h-16">
              {/* Logo/Brand */}
              <div className="flex items-center space-x-3">
                <div 
                  className="w-8 h-8 rounded-lg flex items-center justify-center text-lg"
                  style={{ 
                    background: `linear-gradient(135deg, ${brandConfig.colors.synapticGreen}, ${brandConfig.colors.electricBlue})`,
                    color: brandConfig.colors.trueBlack
                  }}
                >
                  🧠
                </div>
                <span 
                  className="text-xl font-bold"
                  style={{ 
                    fontFamily: brandConfig.typography.fontDisplay,
                    color: brandConfig.colors.pureWhite
                  }}
                >
                  OneVault AI
                </span>
              </div>

              {/* Back button */}
              <button
                onClick={() => navigate('/dashboard')}
                className="px-4 py-2 rounded-lg font-medium transition-all duration-300 hover:scale-105 flex items-center space-x-2"
                style={{
                  background: `linear-gradient(135deg, ${brandConfig.colors.neuralGray}, ${brandConfig.colors.connectionGray})`,
                  color: brandConfig.colors.pureWhite,
                  border: 'none',
                  fontFamily: brandConfig.typography.fontPrimary,
                  fontSize: brandConfig.typography.fontSizeSm
                }}
              >
                <span>←</span>
                <span>Back to Dashboard</span>
              </button>
            </div>
          </div>
        </nav>

        {/* Gallery content */}
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {/* 🎯 Gallery header */}
          <div 
            className="gallery-header mb-8"
            style={{
              background: `linear-gradient(135deg, 
                ${brandConfig.colors.elevatedBlack}95 0%, 
                ${brandConfig.colors.surfaceBlack}90 100%
              )`,
              border: `1px solid ${brandConfig.colors.neuralGray}30`,
              borderRadius: brandConfig.layout.borderRadiusLg,
              padding: brandConfig.spacing.xl,
              backdropFilter: 'blur(20px)',
              position: 'relative',
              overflow: 'hidden'
            }}
          >
        {/* Neural background effect */}
        <div 
          className="absolute inset-0 opacity-5"
          style={{
            background: `radial-gradient(circle at 30% 30%, ${brandConfig.colors.neuralPurple}40 0%, transparent 50%),
                        radial-gradient(circle at 70% 70%, ${brandConfig.colors.electricBlue}40 0%, transparent 50%)`
          }}
        />

        <div className="relative z-10">
          {/* Back button */}
          <button
            onClick={() => navigate('/dashboard')}
            className="mb-4 px-4 py-2 rounded-lg font-medium transition-all duration-300 hover:scale-105"
            style={{
              background: `linear-gradient(135deg, ${brandConfig.colors.neuralGray}, ${brandConfig.colors.connectionGray})`,
              color: brandConfig.colors.pureWhite,
              border: 'none',
              fontFamily: brandConfig.typography.fontPrimary,
              fontSize: brandConfig.typography.fontSizeSm
            }}
          >
            ← Back to Dashboard
          </button>

          {/* Gallery title */}
          <h1 
            className="text-4xl font-bold mb-4"
            style={{
              fontFamily: brandConfig.typography.fontDisplay,
              color: brandConfig.colors.pureWhite,
              textShadow: `0 0 20px ${brandConfig.colors.neuralPurple}30`
            }}
          >
            🤖 {templateConfig.gallery.title}
          </h1>

          <p 
            className="text-lg mb-6"
            style={{
              fontFamily: brandConfig.typography.fontPrimary,
              color: brandConfig.colors.textSecondary,
              lineHeight: brandConfig.typography.lineHeightRelaxed
            }}
          >
            {templateConfig.gallery.description}
          </p>

          {/* Gallery metrics */}
          <div className="flex flex-wrap gap-6">
            {Object.entries(templateConfig.metrics).map(([key, value]) => (
              <div key={key} className="flex items-center space-x-2">
                <div 
                  className="w-2 h-2 rounded-full"
                  style={{
                    background: brandConfig.colors.synapticGreen,
                    boxShadow: `0 0 10px ${brandConfig.colors.synapticGreen}`
                  }}
                />
                <span 
                  className="text-sm font-medium"
                  style={{
                    fontFamily: brandConfig.typography.fontCode,
                    color: brandConfig.colors.textSecondary
                  }}
                >
                  {key.replace(/([A-Z])/g, ' $1').toLowerCase()}: {value}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* 🔍 Search and filters */}
      <div className="search-filters-section mb-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Search */}
          <div className="lg:col-span-2">
            <TemplateSearch 
              searchQuery={searchQuery}
              onSearchChange={setSearchQuery}
            />
          </div>

          {/* Filters */}
          <div className="lg:col-span-1">
            <TemplateFilters 
              selectedFilters={selectedFilters}
              onFiltersChange={setSelectedFilters}
            />
          </div>
        </div>
      </div>

      {/* 🏷️ Category tabs */}
      <div className="category-tabs mb-8">
        <div className="flex flex-wrap gap-3">
          <button
            onClick={() => setSelectedCategory('all')}
            className="px-4 py-2 rounded-lg font-medium transition-all duration-300"
            style={{
              background: selectedCategory === 'all'
                ? `linear-gradient(135deg, ${brandConfig.colors.synapticGreen}, ${brandConfig.colors.electricBlue})`
                : `${brandConfig.colors.elevatedBlack}80`,
              color: brandConfig.colors.pureWhite,
              border: `1px solid ${selectedCategory === 'all' ? brandConfig.colors.synapticGreen : brandConfig.colors.neuralGray}30`,
              fontFamily: brandConfig.typography.fontPrimary,
              fontSize: brandConfig.typography.fontSizeSm
            }}
          >
            All Templates
          </button>

          {templateConfig.categories.map((category) => (
            <button
              key={category.id}
              onClick={() => setSelectedCategory(category.id)}
              className="px-4 py-2 rounded-lg font-medium transition-all duration-300 flex items-center space-x-2"
                             style={{
                 background: selectedCategory === category.id
                   ? `linear-gradient(135deg, ${brandConfig.colors[category.color as keyof typeof brandConfig.colors]}, ${brandConfig.colors[category.color as keyof typeof brandConfig.colors]}80)`
                   : `${brandConfig.colors.elevatedBlack}80`,
                 color: brandConfig.colors.pureWhite,
                 border: `1px solid ${selectedCategory === category.id ? brandConfig.colors[category.color as keyof typeof brandConfig.colors] : brandConfig.colors.neuralGray}30`,
                 fontFamily: brandConfig.typography.fontPrimary,
                 fontSize: brandConfig.typography.fontSizeSm
               }}
             >
               <span>{category.icon}</span>
               <span>{category.name}</span>
               <span 
                 className="px-2 py-1 rounded-full text-xs"
                 style={{
                   background: `${brandConfig.colors[category.color as keyof typeof brandConfig.colors]}20`,
                   color: brandConfig.colors[category.color as keyof typeof brandConfig.colors]
                 }}
               >
                {category.count}
              </span>
            </button>
          ))}
        </div>
      </div>

      {/* 🎯 Templates grid */}
      <div className="templates-grid">
        {filteredTemplates.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredTemplates.map((template, index) => (
              <TemplateCard
                key={template.id}
                template={template}
                index={index}
                canAccess={canAccess}
                onSelect={handleTemplateSelect}
              />
            ))}
          </div>
        ) : (
          // Empty state
          <div 
            className="empty-state text-center py-16"
            style={{
              background: `linear-gradient(135deg, 
                ${brandConfig.colors.elevatedBlack}50 0%, 
                ${brandConfig.colors.surfaceBlack}30 100%
              )`,
              border: `2px dashed ${brandConfig.colors.neuralGray}30`,
              borderRadius: brandConfig.layout.borderRadiusLg,
              padding: brandConfig.spacing['3xl']
            }}
          >
            <div className="text-6xl mb-4">🔍</div>
            <h3 
              className="text-xl font-semibold mb-2"
              style={{
                fontFamily: brandConfig.typography.fontDisplay,
                color: brandConfig.colors.pureWhite
              }}
            >
              {templateConfig.gallery.emptyState}
            </h3>
            <p 
              className="text-sm"
              style={{
                fontFamily: brandConfig.typography.fontPrimary,
                color: brandConfig.colors.textMuted
              }}
            >
              Try adjusting your search or filters to discover more templates
            </p>
          </div>
        )}
      </div>

          {/* 🎨 Neural activity indicator */}
          <div className="mt-8 flex items-center justify-center space-x-2 opacity-40">
            <div 
              className="w-1 h-1 rounded-full animate-pulse"
              style={{ background: brandConfig.colors.neuralPurple }}
            />
            <span 
              className="text-xs font-mono"
              style={{
                fontFamily: brandConfig.typography.fontCode,
                color: brandConfig.colors.textMuted
              }}
            >
              AI TEMPLATES SYNCHRONIZED
            </span>
            <div 
              className="w-1 h-1 rounded-full animate-pulse"
              style={{ 
                background: brandConfig.colors.electricBlue,
                animationDelay: '0.5s'
              }}
            />
          </div>
        </div>
      </div>
    </div>
  );
}; 