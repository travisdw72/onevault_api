import React, { useState } from 'react';
import { templateConfig } from '../../config/templateConfig';
import { brandConfig } from '../../config/brandConfig';

interface TemplateCardProps {
  template: typeof templateConfig.templates[0];
  index: number;
  canAccess: (route: string) => boolean;
  onSelect: (templateId: string) => void;
}

export const TemplateCard: React.FC<TemplateCardProps> = ({ 
  template, 
  index, 
  canAccess, 
  onSelect 
}) => {
  const [isHovered, setIsHovered] = useState(false);
  const [isPressed, setIsPressed] = useState(false);

  // 🎨 Get category configuration
  const categoryConfig = templateConfig.categories.find(cat => cat.id === template.category);
  const categoryColor = categoryConfig?.color || 'neuralGray';
  
  // Helper to safely get colors
  const getColor = (colorKey: string): string => {
    return brandConfig.colors[colorKey as keyof typeof brandConfig.colors] || brandConfig.colors.neuralGray;
  };

  const handleClick = () => {
    if (canAccess(`/templates/${template.id}`)) {
      onSelect(template.id);
    }
  };

  const handleMouseDown = () => setIsPressed(true);
  const handleMouseUp = () => setIsPressed(false);
  const handleMouseLeave = () => {
    setIsHovered(false);
    setIsPressed(false);
  };

  const isAccessible = canAccess(`/templates/${template.id}`);

  return (
    <div
      className="template-card"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={handleMouseLeave}
      onMouseDown={handleMouseDown}
      onMouseUp={handleMouseUp}
      onClick={handleClick}
      style={{
        background: isAccessible
          ? `linear-gradient(135deg, 
              ${getColor(categoryColor)}20 0%, 
              ${getColor(categoryColor)}10 50%,
              ${brandConfig.colors.elevatedBlack}90 100%
            )`
          : `linear-gradient(135deg, 
              ${brandConfig.colors.neuralGray}20 0%, 
              ${brandConfig.colors.connectionGray}10 100%
            )`,
        border: `1px solid ${isAccessible ? getColor(categoryColor) : brandConfig.colors.neuralGray}30`,
        borderRadius: brandConfig.layout.borderRadiusLg,
        padding: brandConfig.spacing.lg,
        position: 'relative',
        overflow: 'hidden',
        cursor: isAccessible ? 'pointer' : 'not-allowed',
        transition: `all ${brandConfig.animations.durationNormal} ${brandConfig.animations.easeOut}`,
        transform: isAccessible && isHovered 
          ? (isPressed ? 'scale(0.98) translateY(1px)' : 'scale(1.05) translateY(-4px)')
          : 'scale(1)',
        boxShadow: isAccessible && isHovered
          ? `0 12px 40px ${getColor(categoryColor)}30, 0 0 0 1px ${getColor(categoryColor)}50`
          : `0 4px 16px ${brandConfig.colors.trueBlack}20`,
        backdropFilter: 'blur(20px)',
        opacity: isAccessible ? 1 : 0.5,
        height: '420px',
        display: 'flex',
        flexDirection: 'column'
      }}
    >
      {/* 🌟 Hover glow effect */}
      <div 
        className="absolute inset-0 transition-opacity duration-300"
        style={{
          background: `radial-gradient(circle at center, ${getColor(categoryColor)}15 0%, transparent 70%)`,
          opacity: isHovered && isAccessible ? 1 : 0
        }}
      />

      {/* ⚡ Neural connection animation */}
      <div 
        className="absolute top-0 left-0 h-full transition-all duration-500"
        style={{
          width: isHovered && isAccessible ? '3px' : '1px',
          background: `linear-gradient(180deg, ${getColor(categoryColor)}, transparent)`,
          opacity: isHovered && isAccessible ? 1 : 0.3
        }}
      />

      <div className="relative z-10 flex flex-col h-full">
        {/* 🎯 Template header */}
        <div className="flex items-start justify-between mb-4">
          <div className="flex items-center space-x-3">
            {/* Category icon */}
            <div 
              className="w-12 h-12 rounded-lg flex items-center justify-center text-2xl"
              style={{
                background: isAccessible
                  ? `linear-gradient(135deg, ${getColor(categoryColor)}, ${getColor(categoryColor)}80)`
                  : `linear-gradient(135deg, ${brandConfig.colors.neuralGray}, ${brandConfig.colors.connectionGray})`,
                boxShadow: isAccessible
                  ? `0 0 20px ${getColor(categoryColor)}40`
                  : 'none'
              }}
            >
              {categoryConfig?.icon || '🤖'}
            </div>

            {/* Difficulty badge */}
            <div 
              className="px-3 py-1 rounded-full text-xs font-medium uppercase tracking-wide"
              style={{
                background: isAccessible
                  ? `${getColor(categoryColor)}20`
                  : `${brandConfig.colors.neuralGray}20`,
                color: isAccessible ? getColor(categoryColor) : brandConfig.colors.textMuted,
                fontFamily: brandConfig.typography.fontCode,
                border: `1px solid ${isAccessible ? getColor(categoryColor) : brandConfig.colors.neuralGray}30`
              }}
            >
              {template.difficulty}
            </div>
          </div>

          {/* Metrics badge */}
          <div 
            className="px-2 py-1 rounded-full text-xs font-bold"
            style={{
              background: isAccessible
                ? `${getColor(categoryColor)}30`
                : `${brandConfig.colors.neuralGray}30`,
              color: isAccessible ? getColor(categoryColor) : brandConfig.colors.textMuted,
              fontFamily: brandConfig.typography.fontCode
            }}
          >
            {template.metrics.accuracy}
          </div>
        </div>

        {/* 📝 Template title and description */}
        <div className="flex-grow mb-4">
          <h3 
            className="text-xl font-semibold mb-3"
            style={{
              fontFamily: brandConfig.typography.fontDisplay,
              color: isAccessible ? brandConfig.colors.pureWhite : brandConfig.colors.textMuted,
              lineHeight: brandConfig.typography.lineHeightTight
            }}
          >
            {template.name}
          </h3>

          <p 
            className="text-sm mb-4"
            style={{
              fontFamily: brandConfig.typography.fontPrimary,
              color: isAccessible ? brandConfig.colors.textSecondary : brandConfig.colors.textMuted,
              lineHeight: brandConfig.typography.lineHeightSnug
            }}
          >
            {template.shortDescription}
          </p>

          {/* 🏷️ Tags */}
          <div className="flex flex-wrap gap-2 mb-4">
            {template.tags.slice(0, 3).map((tag) => (
              <span
                key={tag}
                className="px-2 py-1 rounded text-xs"
                style={{
                  background: `${getColor(categoryColor)}15`,
                  color: isAccessible ? getColor(categoryColor) : brandConfig.colors.textMuted,
                  fontFamily: brandConfig.typography.fontCode,
                  fontSize: brandConfig.typography.fontSizeXs
                }}
              >
                {tag}
              </span>
            ))}
          </div>
        </div>

        {/* 🤖 Agents preview */}
        <div className="mb-4">
          <div className="flex items-center space-x-2 mb-2">
            <span 
              className="text-xs font-medium uppercase tracking-wide"
              style={{
                fontFamily: brandConfig.typography.fontCode,
                color: brandConfig.colors.textSecondary,
                fontSize: brandConfig.typography.fontSizeXs
              }}
            >
              AI Agents ({template.agents.length})
            </span>
          </div>
          
          <div className="flex space-x-2">
            {template.agents.map((agent) => (
              <div
                key={agent.id}
                className="w-8 h-8 rounded-full flex items-center justify-center text-sm"
                style={{
                  background: `linear-gradient(135deg, ${getColor(agent.color)}, ${getColor(agent.color)}80)`,
                  boxShadow: `0 0 10px ${getColor(agent.color)}30`
                }}
                title={agent.name}
              >
                {agent.icon}
              </div>
            ))}
          </div>
        </div>

        {/* 📊 Workflow metrics */}
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <div className="flex items-center space-x-1">
              <span 
                className="text-xs"
                style={{
                  fontFamily: brandConfig.typography.fontCode,
                  color: brandConfig.colors.textMuted
                }}
              >
                ⏱️
              </span>
              <span 
                className="text-xs font-medium"
                style={{
                  fontFamily: brandConfig.typography.fontCode,
                  color: brandConfig.colors.textSecondary
                }}
              >
                {template.estimatedTime}
              </span>
            </div>

            <div className="flex items-center space-x-1">
              <span 
                className="text-xs"
                style={{
                  fontFamily: brandConfig.typography.fontCode,
                  color: brandConfig.colors.textMuted
                }}
              >
                🔗
              </span>
              <span 
                className="text-xs font-medium"
                style={{
                  fontFamily: brandConfig.typography.fontCode,
                  color: brandConfig.colors.textSecondary
                }}
              >
                {template.workflow.apiCalls} API calls
              </span>
            </div>
          </div>

          {/* Launch indicator */}
          {isAccessible && (
            <span 
              className="text-sm font-mono opacity-60"
              style={{
                fontFamily: brandConfig.typography.fontCode,
                color: brandConfig.colors.textSecondary,
                transform: isHovered ? 'translateX(4px)' : 'translateX(0px)',
                transition: `transform ${brandConfig.animations.durationFast}`
              }}
            >
              →
            </span>
          )}
        </div>

        {/* ⚡ Neural pulse effect on hover */}
        <div 
          className="absolute bottom-0 left-0 right-0 h-1 transition-all duration-300"
          style={{
            background: isAccessible
              ? `linear-gradient(90deg, ${getColor(categoryColor)}, transparent)`
              : 'transparent',
            opacity: isHovered && isAccessible ? 1 : 0
          }}
        />
      </div>
    </div>
  );
}; 