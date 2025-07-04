import React, { useState, useEffect } from 'react';
import { templateConfig } from '../../config/templateConfig';
import { brandConfig } from '../../config/brandConfig';

interface AgentNodeProps {
  agent: typeof templateConfig.templates[0]['agents'][0];
  isActive?: boolean;
  size?: 'small' | 'medium' | 'large';
  className?: string;
  onClick?: () => void;
}

interface Dendrite {
  id: string;
  angle: number;
  length: number;
  branches: number;
}

export const AgentNode: React.FC<AgentNodeProps> = ({ 
  agent, 
  isActive = false, 
  size = 'medium',
  className = '',
  onClick 
}) => {
  const [isHovered, setIsHovered] = useState(false);
  const [dendrites, setDendrites] = useState<Dendrite[]>([]);
  const [neuralActivity, setNeuralActivity] = useState(0);
  const [iconScale, setIconScale] = useState(1); // Progressive disclosure state
  const [iconLocked, setIconLocked] = useState(false); // Click-to-lock behavior

  // Helper to safely get colors
  const getColor = (colorKey: string): string => {
    return brandConfig.colors[colorKey as keyof typeof brandConfig.colors] || brandConfig.colors.neuralGray;
  };

  // Enhanced size configurations for neural nodes
  const sizeConfig = {
    small: { 
      width: 56, 
      height: 56, 
      iconSize: '16px', 
      fontSize: brandConfig.typography.fontSizeXs,
      dendriteCount: 3,
      synapseSize: 2,
      dendriteLength: 20
    },
    medium: { 
      width: 72, 
      height: 72, 
      iconSize: '20px', 
      fontSize: brandConfig.typography.fontSizeSm,
      dendriteCount: 5,
      synapseSize: 3,
      dendriteLength: 25
    },
    large: { 
      width: 96, 
      height: 96, 
      iconSize: '28px', 
      fontSize: brandConfig.typography.fontSizeBase,
      dendriteCount: 7,
      synapseSize: 4,
      dendriteLength: 30
    }
  };

  const currentSize = sizeConfig[size];
  const dendriteExtension = currentSize.dendriteLength;
  const totalSize = Math.max(currentSize.width, currentSize.height) + (dendriteExtension * 2);

  // Generate dendrites on mount
  useEffect(() => {
    const newDendrites: Dendrite[] = [];
    for (let i = 0; i < currentSize.dendriteCount; i++) {
      newDendrites.push({
        id: `dendrite-${i}`,
        angle: (360 / currentSize.dendriteCount) * i + Math.random() * 40 - 20,
        length: 15 + Math.random() * 15, // Reduced max length
        branches: Math.floor(Math.random() * 3) + 1
      });
    }
    setDendrites(newDendrites);
  }, [currentSize.dendriteCount]);

  // Progressive disclosure based on hover and interaction
  useEffect(() => {
    if (isHovered || iconLocked) {
      setIconScale(1.4); // Expanded state (140%)
    } else {
      setIconScale(1); // Default state (100%)
    }
  }, [isHovered, iconLocked]);

  // Neural activity animation
  useEffect(() => {
    if (!isActive) return;

    const interval = setInterval(() => {
      setNeuralActivity(prev => (prev + 1) % 100);
    }, 50);

    return () => clearInterval(interval);
  }, [isActive]);

  // Generate dendrite path - updated for better positioning
  const generateDendritePath = (dendrite: Dendrite, centerX: number, centerY: number) => {
    const angle = (dendrite.angle * Math.PI) / 180;
    const somaRadius = currentSize.width / 2;
    
    // Start from edge of soma, not center
    const startX = centerX + Math.cos(angle) * somaRadius;
    const startY = centerY + Math.sin(angle) * somaRadius;
    
    const mainEndX = centerX + Math.cos(angle) * (somaRadius + dendrite.length);
    const mainEndY = centerY + Math.sin(angle) * (somaRadius + dendrite.length);
    
    let path = `M ${startX} ${startY} L ${mainEndX} ${mainEndY}`;
    
    // Add branches
    for (let i = 0; i < dendrite.branches; i++) {
      const branchRatio = 0.6 + (i * 0.2);
      const branchStartX = startX + Math.cos(angle) * dendrite.length * branchRatio;
      const branchStartY = startY + Math.sin(angle) * dendrite.length * branchRatio;
      
      const branchAngle = angle + (Math.random() - 0.5) * 1.2;
      const branchLength = dendrite.length * (0.3 + Math.random() * 0.4);
      
      const branchEndX = branchStartX + Math.cos(branchAngle) * branchLength;
      const branchEndY = branchStartY + Math.sin(branchAngle) * branchLength;
      
      path += ` M ${branchStartX} ${branchStartY} L ${branchEndX} ${branchEndY}`;
    }
    
    return path;
  };

  // Calculate center positions for perfect alignment
  const centerX = totalSize / 2;
  const centerY = totalSize / 2;

  return (
    <div 
      className={`neural-agent-node ${className}`}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      onClick={() => {
        setIconLocked(!iconLocked); // Toggle icon lock
        onClick?.(); // Call original onClick if provided
      }}
      style={{
        width: `${totalSize}px`,
        height: `${totalSize}px`,
        position: 'relative',
        cursor: onClick ? 'pointer' : 'default',
        transition: `all ${brandConfig.animations.durationNormal} ${brandConfig.animations.easeOut}`,
        transform: isHovered 
          ? 'scale(1.05) translateY(-2px)' 
          : 'scale(1)',
        filter: isActive ? 'brightness(1.1)' : 'brightness(1)'
      }}
      data-agent-id={agent.id}
      data-center-x={centerX}
      data-center-y={centerY}
    >
      {/* Dendrite network */}
      <svg 
        className="absolute inset-0 w-full h-full pointer-events-none"
        style={{ zIndex: 1 }}
      >
        <defs>
          <radialGradient id={`dendriteGradient-${agent.id}`}>
            <stop offset="0%" stopColor={getColor(agent.color)} stopOpacity="0.8" />
            <stop offset="100%" stopColor={getColor(agent.color)} stopOpacity="0.2" />
          </radialGradient>
          
          <filter id={`dendriteGlow-${agent.id}`}>
            <feGaussianBlur stdDeviation="1" result="coloredBlur"/>
            <feMerge> 
              <feMergeNode in="coloredBlur"/>
              <feMergeNode in="SourceGraphic"/>
            </feMerge>
          </filter>
        </defs>

        {/* Render dendrites */}
        {dendrites.map((dendrite, index) => (
          <g key={dendrite.id}>
            {/* Dendrite glow */}
            <path
              d={generateDendritePath(dendrite, centerX, centerY)}
              stroke={getColor(agent.color)}
              strokeWidth="3"
              fill="none"
              opacity="0.3"
              style={{
                filter: 'blur(1px)'
              }}
            />
            
            {/* Main dendrite */}
            <path
              d={generateDendritePath(dendrite, centerX, centerY)}
              stroke={`url(#dendriteGradient-${agent.id})`}
              strokeWidth="1.5"
              fill="none"
              style={{
                filter: `url(#dendriteGlow-${agent.id})`,
                animation: isActive ? 'neural-pulse 3s ease-in-out infinite' : 'none',
                animationDelay: `${index * 0.2}s`
              }}
            />
            
            {/* Synaptic terminals */}
            {[...Array(dendrite.branches + 1)].map((_, terminalIndex) => {
              const angle = (dendrite.angle * Math.PI) / 180;
              const somaRadius = currentSize.width / 2;
              const ratio = terminalIndex === 0 ? 1 : 0.6 + (terminalIndex * 0.2);
              const terminalX = centerX + Math.cos(angle) * (somaRadius + dendrite.length * ratio);
              const terminalY = centerY + Math.sin(angle) * (somaRadius + dendrite.length * ratio);
              
              return (
                <circle
                  key={`terminal-${terminalIndex}`}
                  cx={terminalX}
                  cy={terminalY}
                  r={currentSize.synapseSize}
                  fill={getColor(agent.color)}
                  opacity={isActive ? 0.8 : 0.4}
                  style={{
                    animation: isActive ? 'neural-ping 2s ease-out infinite' : 'none',
                    animationDelay: `${index * 0.3 + terminalIndex * 0.1}s`
                  }}
                />
              );
            })}
          </g>
        ))}
      </svg>

      {/* Neural cell body (soma) - perfectly centered */}
      <div 
        className="neural-soma absolute"
        style={{
          width: `${currentSize.width}px`,
          height: `${currentSize.height}px`,
          left: `${centerX - currentSize.width / 2}px`,
          top: `${centerY - currentSize.height / 2}px`,
          background: `radial-gradient(circle at 30% 30%, 
            ${getColor(agent.color)}95 0%, 
            ${getColor(agent.color)}80 40%,
            ${getColor(agent.color)}60 100%
          )`,
          border: `3px solid ${isActive ? brandConfig.colors.synapticGreen : getColor(agent.color)}`,
          borderRadius: '50%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          position: 'relative',
          zIndex: 5,
          boxShadow: isActive || isHovered
            ? `0 12px 40px ${getColor(agent.color)}50, 
               0 0 20px ${getColor(agent.color)}60,
               inset 0 0 20px ${getColor(agent.color)}30`
            : `0 6px 20px ${brandConfig.colors.trueBlack}40,
               inset 0 0 10px ${getColor(agent.color)}20`,
          backdropFilter: 'blur(20px)',
          overflow: 'hidden',
          transition: `all ${brandConfig.animations.durationNormal} ${brandConfig.animations.easeOut}`
        }}
      >
        {/* Cell membrane texture */}
        <div 
          className="absolute inset-0 rounded-full"
          style={{
            background: `radial-gradient(circle at 60% 40%, ${brandConfig.colors.pureWhite}08 0%, transparent 50%),
                        radial-gradient(circle at 20% 80%, ${getColor(agent.color)}15 0%, transparent 40%)`,
            animation: isActive ? 'neural-pulse 4s ease-in-out infinite' : 'none'
          }}
        />

        {/* Neural activity visualization */}
        {isActive && (
          <div 
            className="absolute inset-0 rounded-full"
            style={{
              background: `conic-gradient(from ${neuralActivity * 3.6}deg, 
                ${getColor(agent.color)}40 0deg, 
                transparent 180deg, 
                ${getColor(agent.color)}40 360deg)`,
              animation: 'spin 3s linear infinite'
            }}
          />
        )}

        {/* Neural Core - Always visible for clean neural network aesthetic */}
        <div 
          className="neural-core relative z-5"
          style={{
            width: '12px',
            height: '12px',
            borderRadius: '50%',
            background: `radial-gradient(circle, ${getColor(agent.color)}FF 0%, ${getColor(agent.color)}80 70%, transparent 100%)`,
            position: 'absolute',
            left: '50%',
            top: '50%',
            transform: 'translate(-50%, -50%)',
            animation: isActive ? 'neural-ping 3s ease-out infinite' : 'none',
            opacity: (isHovered || iconLocked) ? 0.3 : 0.9,  // Dimmer when icon is visible
            transition: `all ${brandConfig.animations.durationNormal} ${brandConfig.animations.easeOut}`
          }}
        />

        {/* Agent Icon - Progressive Disclosure on Neural Activation */}
        <div 
          className="agent-icon relative z-10"
          style={{
            fontSize: currentSize.iconSize,
            filter: isActive ? 'brightness(1.3) drop-shadow(0 0 8px rgba(255,255,255,0.5))' : 'brightness(1.1)',
            textShadow: `0 0 10px ${getColor(agent.color)}80`,
            animation: isActive ? 'neural-pulse 2s ease-in-out infinite' : 'none',
            transform: `scale(${iconScale}) translate(0, 0)`,
            transition: `all ${brandConfig.animations.durationFast} ${brandConfig.animations.easeOut}`,
            transformOrigin: 'center',
            opacity: 1,  // Always visible - positioning should be perfect now
            pointerEvents: 'none'  // Don't interfere with node clicking
          }}
        >
          {agent.icon}
        </div>

        {/* Action potential ripples when active */}
        {isActive && (
          <>
            <div 
              className="absolute inset-0 rounded-full border-2"
              style={{
                borderColor: brandConfig.colors.electricBlue,
                animation: 'neural-ping 1.5s ease-out infinite',
                animationDelay: '0s'
              }}
            />
            <div 
              className="absolute inset-0 rounded-full border-2"
              style={{
                borderColor: brandConfig.colors.synapticGreen,
                animation: 'neural-ping 1.5s ease-out infinite',
                animationDelay: '0.3s'
              }}
            />
            <div 
              className="absolute inset-0 rounded-full border-2"
              style={{
                borderColor: getColor(agent.color),
                animation: 'neural-ping 1.5s ease-out infinite',
                animationDelay: '0.6s'
              }}
            />
          </>
        )}
      </div>

      {/* Agent type indicator - enhanced */}
      <div 
        className="absolute z-10"
        style={{
          bottom: '15px',
          right: '15px',
          width: `${Math.max(16, currentSize.width * 0.2)}px`,
          height: `${Math.max(16, currentSize.height * 0.2)}px`,
          borderRadius: '50%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: `linear-gradient(135deg, 
            ${brandConfig.colors.elevatedBlack}95, 
            ${brandConfig.colors.surfaceBlack}90)`,
          border: `2px solid ${getColor(agent.color)}90`,
          color: brandConfig.colors.pureWhite,
          fontSize: brandConfig.typography.fontSizeNano,
          boxShadow: `0 0 15px ${getColor(agent.color)}50`
        }}
      >
        {agent.type === 'controller' ? '🎛️' : 
         agent.type === 'analyzer' ? '🔍' : 
         agent.type === 'synthesizer' ? '📋' : '🤖'}
      </div>

      {/* Enhanced progressive disclosure tooltip */}
      {isHovered && (
        <div 
          className="absolute z-20"
          style={{
            top: `${totalSize + 10}px`,
            left: '50%',
            transform: 'translateX(-50%)',
            minWidth: '200px',
            maxWidth: '280px',
            padding: `${brandConfig.spacing.md} ${brandConfig.spacing.lg}`,
            background: `linear-gradient(135deg, 
              ${brandConfig.colors.elevatedBlack}98 0%, 
              ${brandConfig.colors.surfaceBlack}95 100%
            )`,
            border: `2px solid ${getColor(agent.color)}60`,
            borderRadius: brandConfig.layout.borderRadiusLg,
            backdropFilter: 'blur(30px)',
            boxShadow: `0 25px 80px ${brandConfig.colors.trueBlack}70,
                       0 0 40px ${getColor(agent.color)}40,
                       inset 0 1px 0 ${brandConfig.colors.pureWhite}10`,
            animation: 'tooltip-entrance 0.3s ease-out',
            opacity: iconScale > 1 ? 1 : 0.95
          }}
        >
          {/* Neural activity header */}
          <div className="flex items-center justify-between mb-2">
            <div 
              className="font-bold text-sm flex items-center gap-2"
              style={{
                fontFamily: brandConfig.typography.fontDisplay,
                color: brandConfig.colors.pureWhite,
                fontSize: brandConfig.typography.fontSizeSm
              }}
            >
              {agent.name}
              {iconLocked && <span style={{ fontSize: '10px' }}>🔒</span>}
            </div>
            <div 
              className="w-2 h-2 rounded-full"
              style={{
                background: isActive ? brandConfig.colors.synapticGreen : brandConfig.colors.neuralGray,
                boxShadow: isActive ? `0 0 8px ${brandConfig.colors.synapticGreen}` : 'none',
                animation: isActive ? 'pulse 1s ease-in-out infinite' : 'none'
              }}
            />
          </div>
          
          {/* Agent description */}
          <div 
            className="text-xs mb-3"
            style={{
              fontFamily: brandConfig.typography.fontPrimary,
              color: brandConfig.colors.textSecondary,
              fontSize: brandConfig.typography.fontSizeXs,
              lineHeight: brandConfig.typography.lineHeightSnug
            }}
          >
            {agent.description}
          </div>

          {/* Neural metrics */}
          <div className="flex items-center justify-between text-xs">
            <span 
              style={{
                fontFamily: brandConfig.typography.fontCode,
                color: brandConfig.colors.textMuted
              }}
            >
              TYPE: {agent.type.toUpperCase()}
            </span>
            <span 
              style={{
                fontFamily: brandConfig.typography.fontCode,
                color: getColor(agent.color)
              }}
            >
              {dendrites.length} DENDRITES
            </span>
          </div>
          
          {/* Tooltip arrow */}
          <div 
            className="absolute w-3 h-3 rotate-45"
            style={{
              top: '-6px',
              left: '50%',
              transform: 'translateX(-50%) rotate(45deg)',
              background: brandConfig.colors.elevatedBlack,
              border: `1px solid ${getColor(agent.color)}50`,
              borderBottom: 'none',
              borderRight: 'none'
            }}
          />
        </div>
      )}
    </div>
  );
}; 