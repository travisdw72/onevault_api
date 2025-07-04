import React, { useState, useEffect, useRef, useCallback } from 'react';
import { templateConfig } from '../../config/templateConfig';
import { brandConfig } from '../../config/brandConfig';
import { AgentNode } from './AgentNode';

interface WorkflowCanvasProps {
  template: typeof templateConfig.templates[0];
  isActive?: boolean;
  className?: string;
}

interface Connection {
  from: string;
  to: string;
  type: 'data' | 'control' | 'feedback';
  animated?: boolean;
  strength?: number; // 0-1 for connection strength visualization
}

interface ViewState {
  zoom: number;
  panX: number;
  panY: number;
  isFullscreen: boolean;
}

interface NeuralSignal {
  id: string;
  connectionId: string;
  progress: number; // 0-1 along path
  speed: number;
  intensity: number;
}

export const WorkflowCanvas: React.FC<WorkflowCanvasProps> = ({ 
  template, 
  isActive = false, 
  className = '' 
}) => {
  const svgRef = useRef<SVGSVGElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // Enhanced connection state with neural properties
  const [connections] = useState<Connection[]>([
    { from: 'orchestrator', to: 'investigator', type: 'data', animated: true, strength: 0.9 },
    { from: 'investigator', to: 'compiler', type: 'data', animated: true, strength: 0.8 },
    { from: 'compiler', to: 'orchestrator', type: 'feedback', animated: false, strength: 0.6 }
  ]);

  // Enhanced view state for zoom/pan
  const [viewState, setViewState] = useState<ViewState>({
    zoom: 0.8, // Default to 80% zoom for better overview
    panX: 0,
    panY: 0,
    isFullscreen: false
  });

  // Neural signals flowing through connections
  const [neuralSignals, setNeuralSignals] = useState<NeuralSignal[]>([]);

  // Dynamic canvas dimensions based on fullscreen state
  const canvasWidth = viewState.isFullscreen ? window.innerWidth - 40 : 800;
  const canvasHeight = viewState.isFullscreen ? window.innerHeight - 80 : 600;
  const centerX = canvasWidth / 2;
  const centerY = canvasHeight / 2;

  // Generate neural signals periodically when active
  useEffect(() => {
    if (!isActive) return;

    const generateSignal = () => {
      const activeConnections = connections.filter(c => c.animated);
      if (activeConnections.length === 0) return;

      const connection = activeConnections[Math.floor(Math.random() * activeConnections.length)];
      const newSignal: NeuralSignal = {
        id: `signal-${Date.now()}-${Math.random()}`,
        connectionId: `${connection.from}-${connection.to}`,
        progress: 0,
        speed: 0.01 + Math.random() * 0.02, // Variable signal speed
        intensity: 0.7 + Math.random() * 0.3 // Variable intensity
      };

      setNeuralSignals(prev => [...prev, newSignal]);
    };

    const interval = setInterval(generateSignal, 800 + Math.random() * 1200);
    return () => clearInterval(interval);
  }, [isActive, connections]);

  // Update neural signal positions
  useEffect(() => {
    if (neuralSignals.length === 0) return;

    const animate = () => {
      setNeuralSignals(prev => 
        prev
          .map(signal => ({
            ...signal,
            progress: signal.progress + signal.speed
          }))
          .filter(signal => signal.progress < 1.1) // Remove completed signals
      );
    };

    const animationFrame = requestAnimationFrame(animate);
    return () => cancelAnimationFrame(animationFrame);
  }, [neuralSignals]);

  // Enhanced agent positioning - simplified for unified coordinate system
  const getAgentPosition = useCallback((index: number, total: number) => {
    if (total === 3) {
      // Triangular layout for 3 agents - coordinates in untransformed space
      const positions = [
        { x: centerX, y: centerY - 140 }, // Top
        { x: centerX - 130, y: centerY + 90 }, // Bottom left  
        { x: centerX + 130, y: centerY + 90 }  // Bottom right
      ];
      return positions[index] || { x: centerX, y: centerY };
    } else {
      // Circular layout for other counts
      const angle = (index * 2 * Math.PI) / total - Math.PI / 2;
      const radius = 150;
      
      return {
        x: centerX + radius * Math.cos(angle),
        y: centerY + radius * Math.sin(angle)
      };
    }
  }, [centerX, centerY]);

  // Simplified soma center calculation - no manual transforms needed
  const getSomaCenter = useCallback((agentId: string) => {
    const agentIndex = template.agents.findIndex(agent => agent.id === agentId);
    if (agentIndex === -1) return { x: centerX, y: centerY };
    
    // Direct position calculation - SVG now inherits same transforms as agents
    const position = getAgentPosition(agentIndex, template.agents.length);
    
    console.log(`🎯 Agent ${agentId} soma center: (${position.x.toFixed(1)}, ${position.y.toFixed(1)})`);
    
    return position;
  }, [getAgentPosition, template.agents, centerX, centerY]);

  // Enhanced neural pathway generation with simplified coordinates
  const getNeuralPath = useCallback((from: string, to: string, connection: Connection) => {
    const fromCenter = getSomaCenter(from);
    const toCenter = getSomaCenter(to);
    
    if (!fromCenter || !toCenter) return '';
    
    // Calculate direction vector
    const dx = toCenter.x - fromCenter.x;
    const dy = toCenter.y - fromCenter.y;
    const distance = Math.sqrt(dx * dx + dy * dy);
    
    if (distance === 0) return '';
    
    // Normalize direction vector
    const dirX = dx / distance;
    const dirY = dy / distance;
    
    // Soma radius - now fixed size since scaling handled by container transform
    const somaRadius = 36; // Half of medium size (72px)
    
    // Calculate edge points (start from soma edge, end at soma edge)
    const fromPos = {
      x: fromCenter.x + dirX * somaRadius,
      y: fromCenter.y + dirY * somaRadius
    };
    
    const toPos = {
      x: toCenter.x - dirX * somaRadius,
      y: toCenter.y - dirY * somaRadius
    };
    
    // Recalculate control points for edge-to-edge connection
    const edgeDx = toPos.x - fromPos.x;
    const edgeDy = toPos.y - fromPos.y;
    const edgeDistance = Math.sqrt(edgeDx * edgeDx + edgeDy * edgeDy);
    
    // Create organic curve
    const curvature = 0.15 + (connection.strength || 0.5) * 0.1;
    const perpX = -edgeDy / edgeDistance;
    const perpY = edgeDx / edgeDistance;
    
    const midX = (fromPos.x + toPos.x) / 2;
    const midY = (fromPos.y + toPos.y) / 2;
    
    const offset1 = edgeDistance * curvature * 0.3;
    const offset2 = edgeDistance * curvature * 0.6;
    
    const cp1X = fromPos.x + edgeDx * 0.25 + perpX * offset1;
    const cp1Y = fromPos.y + edgeDy * 0.25 + perpY * offset1;
    
    const cp2X = midX + perpX * offset2;
    const cp2Y = midY + perpY * offset2;
    
    const cp3X = toPos.x - edgeDx * 0.25 + perpX * offset1;
    const cp3Y = toPos.y - edgeDy * 0.25 + perpY * offset1;
    
    console.log(`Path ${from}->${to}: from(${fromPos.x.toFixed(1)},${fromPos.y.toFixed(1)}) to(${toPos.x.toFixed(1)},${toPos.y.toFixed(1)})`);
    
    return `M ${fromPos.x} ${fromPos.y} 
            C ${cp1X} ${cp1Y}, ${cp2X} ${cp2Y}, ${midX} ${midY}
            S ${cp3X} ${cp3Y}, ${toPos.x} ${toPos.y}`;
  }, [getSomaCenter, viewState.zoom]);

  // Get agent color by ID for pathway gradients
  const getAgentColor = useCallback((agentId: string) => {
    const agent = template.agents.find(a => a.id === agentId);
    if (!agent) {
      console.warn(`Agent not found: ${agentId}`);
      return brandConfig.colors.neuralGray;
    }
    
    const colorKey = agent.color as keyof typeof brandConfig.colors;
    const resolvedColor = brandConfig.colors[colorKey];
    
    if (!resolvedColor) {
      console.warn(`Color not found for key: ${colorKey}, agent: ${agentId}`);
      return brandConfig.colors.neuralGray;
    }
    
    console.log(`Agent ${agentId} (${agent.color}) -> ${resolvedColor}`);
    return resolvedColor;
  }, [template.agents]);

  // Zoom controls
  const handleZoom = useCallback((delta: number) => {
    setViewState(prev => ({
      ...prev,
      zoom: Math.max(0.3, Math.min(3, prev.zoom + delta))
    }));
  }, []);

  // Pan controls
  const handlePan = useCallback((deltaX: number, deltaY: number) => {
    setViewState(prev => ({
      ...prev,
      panX: prev.panX + deltaX,
      panY: prev.panY + deltaY
    }));
  }, []);

  // Fullscreen toggle
  const toggleFullscreen = useCallback(() => {
    setViewState(prev => ({
      ...prev,
      isFullscreen: !prev.isFullscreen,
      zoom: prev.isFullscreen ? 1 : 0.8, // Adjust zoom for fullscreen
      panX: 0,
      panY: 0
    }));
  }, []);

  // Mouse wheel zoom
  const handleWheel = useCallback((e: React.WheelEvent) => {
    e.preventDefault();
    const delta = e.deltaY > 0 ? -0.1 : 0.1;
    handleZoom(delta);
  }, [handleZoom]);

  // Get signal position along path - updated for unified coordinate system
  const getSignalPosition = useCallback((connectionId: string, progress: number) => {
    const pathElement = svgRef.current?.querySelector(`[data-connection="${connectionId}"]`) as SVGPathElement;
    if (!pathElement) {
      console.warn(`⚠️ Path element not found for connection: ${connectionId}`);
      return { x: 0, y: 0 };
    }

    try {
      const pathLength = pathElement.getTotalLength();
      const point = pathElement.getPointAtLength(pathLength * progress);
      
      // Coordinates are now in the same transformed space as agents - no conversion needed
      console.log(`🔄 Signal position for ${connectionId} at ${(progress * 100).toFixed(1)}%: (${point.x.toFixed(1)}, ${point.y.toFixed(1)})`);
      
      return { x: point.x, y: point.y };
    } catch (error) {
      console.error(`❌ Error getting signal position for ${connectionId}:`, error);
      return { x: 0, y: 0 };
    }
  }, []);

  // Coordinate validation function for debugging alignment
  const validateCoordinateAlignment = useCallback(() => {
    console.group('🎯 Coordinate Alignment Validation');
    
    template.agents.forEach((agent, index) => {
      const agentPosition = getAgentPosition(index, template.agents.length);
      const somaCenter = getSomaCenter(agent.id);
      
      const positionMatch = Math.abs(agentPosition.x - somaCenter.x) < 0.1 && Math.abs(agentPosition.y - somaCenter.y) < 0.1;
      
      console.log(
        `${positionMatch ? '✅' : '❌'} Agent ${agent.id}:`,
        `Position(${agentPosition.x.toFixed(1)}, ${agentPosition.y.toFixed(1)})`,
        `Soma(${somaCenter.x.toFixed(1)}, ${somaCenter.y.toFixed(1)})`,
        positionMatch ? 'ALIGNED' : 'MISALIGNED'
      );
    });
    
    connections.forEach(connection => {
      const fromCenter = getSomaCenter(connection.from);
      const toCenter = getSomaCenter(connection.to);
      const pathData = getNeuralPath(connection.from, connection.to, connection);
      
      if (pathData) {
        console.log(
          `🔗 Connection ${connection.from} → ${connection.to}:`,
          `From(${fromCenter.x.toFixed(1)}, ${fromCenter.y.toFixed(1)})`,
          `To(${toCenter.x.toFixed(1)}, ${toCenter.y.toFixed(1)})`
        );
      }
    });
    
    console.groupEnd();
  }, [template.agents, connections, getAgentPosition, getSomaCenter, getNeuralPath]);

  // Run validation when view state changes
  useEffect(() => {
    const validationTimer = setTimeout(() => {
      validateCoordinateAlignment();
    }, 100); // Small delay to ensure DOM is updated
    
    return () => clearTimeout(validationTimer);
  }, [validateCoordinateAlignment, viewState]);

  return (
    <div 
      className={`neural-workflow-canvas ${className} ${viewState.isFullscreen ? 'fixed inset-0 z-50' : 'relative'}`}
      ref={containerRef}
      style={{
        background: `radial-gradient(ellipse at center, 
          ${brandConfig.colors.elevatedBlack}95 0%, 
          ${brandConfig.colors.trueBlack}98 70%,
          ${brandConfig.colors.surfaceBlack}95 100%
        )`,
        border: viewState.isFullscreen ? 'none' : `1px solid ${isActive ? brandConfig.colors.synapticGreen : brandConfig.colors.neuralGray}30`,
        borderRadius: viewState.isFullscreen ? '0' : brandConfig.layout.borderRadiusLg,
        padding: brandConfig.spacing.lg,
        overflow: 'hidden',
        height: viewState.isFullscreen ? '100vh' : `${canvasHeight}px`,
        width: viewState.isFullscreen ? '100vw' : '100%',
        backdropFilter: 'blur(20px)',
        cursor: 'grab'
      }}
      onWheel={handleWheel}
    >
      {/* Neural background grid */}
      <div 
        className="absolute inset-0"
        style={{
          background: `
            radial-gradient(circle at 20% 20%, ${brandConfig.colors.neuralPurple}08 0%, transparent 40%),
            radial-gradient(circle at 80% 30%, ${brandConfig.colors.electricBlue}08 0%, transparent 40%),
            radial-gradient(circle at 40% 80%, ${brandConfig.colors.synapticGreen}06 0%, transparent 40%),
            linear-gradient(90deg, ${brandConfig.colors.neuralGray}05 1px, transparent 1px),
            linear-gradient(${brandConfig.colors.neuralGray}05 1px, transparent 1px)
          `,
          backgroundSize: `
            100% 100%,
            100% 100%, 
            100% 100%,
            ${40 * viewState.zoom}px ${40 * viewState.zoom}px,
            ${40 * viewState.zoom}px ${40 * viewState.zoom}px
          `,
          transform: `translate(${viewState.panX}px, ${viewState.panY}px)`,
          opacity: 0.3
        }}
      />

      {/* Control panel */}
      <div 
        className="absolute top-4 right-4 flex flex-col space-y-2 z-20"
        style={{
          background: `linear-gradient(135deg, 
            ${brandConfig.colors.elevatedBlack}90 0%, 
            ${brandConfig.colors.surfaceBlack}85 100%
          )`,
          backdropFilter: 'blur(20px)',
          border: `1px solid ${brandConfig.colors.neuralGray}30`,
                     borderRadius: brandConfig.layout.borderRadius,
          padding: brandConfig.spacing.sm
        }}
      >
        {/* Zoom controls */}
        <div className="flex flex-col space-y-1">
          <button
            onClick={() => handleZoom(0.2)}
            className="w-8 h-8 rounded flex items-center justify-center text-sm font-bold transition-all duration-200 hover:scale-110"
            style={{
              background: `linear-gradient(135deg, ${brandConfig.colors.neuralPurple}60, ${brandConfig.colors.electricBlue}60)`,
              color: brandConfig.colors.pureWhite,
              border: `1px solid ${brandConfig.colors.neuralPurple}40`
            }}
          >
            +
          </button>
          
          <div 
            className="w-8 h-6 rounded flex items-center justify-center text-xs"
            style={{
              background: brandConfig.colors.surfaceBlack,
              color: brandConfig.colors.textSecondary,
              fontFamily: brandConfig.typography.fontCode
            }}
          >
            {Math.round(viewState.zoom * 100)}%
          </div>
          
          <button
            onClick={() => handleZoom(-0.2)}
            className="w-8 h-8 rounded flex items-center justify-center text-sm font-bold transition-all duration-200 hover:scale-110"
            style={{
              background: `linear-gradient(135deg, ${brandConfig.colors.neuralPurple}60, ${brandConfig.colors.electricBlue}60)`,
              color: brandConfig.colors.pureWhite,
              border: `1px solid ${brandConfig.colors.neuralPurple}40`
            }}
          >
            −
          </button>
        </div>

        {/* Fullscreen toggle */}
        <button
          onClick={toggleFullscreen}
          className="w-8 h-8 rounded flex items-center justify-center text-xs transition-all duration-200 hover:scale-110"
          style={{
            background: `linear-gradient(135deg, ${brandConfig.colors.synapticGreen}60, ${brandConfig.colors.electricBlue}60)`,
            color: brandConfig.colors.pureWhite,
            border: `1px solid ${brandConfig.colors.synapticGreen}40`
          }}
        >
          {viewState.isFullscreen ? '⌃' : '⌄'}
        </button>

        {/* Reset view */}
        <button
          onClick={() => setViewState(prev => ({ ...prev, zoom: 1, panX: 0, panY: 0 }))}
          className="w-8 h-8 rounded flex items-center justify-center text-xs transition-all duration-200 hover:scale-110"
          style={{
            background: `linear-gradient(135deg, ${brandConfig.colors.activeGold}60, ${brandConfig.colors.fusionOrange}60)`,
            color: brandConfig.colors.pureWhite,
            border: `1px solid ${brandConfig.colors.activeGold}40`
          }}
        >
          ⌂
        </button>
      </div>

      {/* Canvas header */}
      {!viewState.isFullscreen && (
        <div className="canvas-header mb-6 relative z-10">
          <div className="flex items-center justify-between">
            <h3 
              className="text-xl font-bold"
              style={{
                fontFamily: brandConfig.typography.fontDisplay,
                color: brandConfig.colors.pureWhite,
                textShadow: `0 0 20px ${brandConfig.colors.synapticGreen}40`
              }}
            >
              🧠 Neural Network Workflow
            </h3>
            
            <div className="flex items-center space-x-3">
              <div 
                className="w-3 h-3 rounded-full"
                style={{
                  background: isActive ? brandConfig.colors.synapticGreen : brandConfig.colors.neuralGray,
                  boxShadow: isActive ? `0 0 15px ${brandConfig.colors.synapticGreen}` : 'none',
                  animation: isActive ? 'pulse 2s ease-in-out infinite' : 'none'
                }}
              />
              <span 
                className="text-sm font-mono"
                style={{
                  fontFamily: brandConfig.typography.fontCode,
                  color: isActive ? brandConfig.colors.synapticGreen : brandConfig.colors.textMuted
                }}
              >
                {isActive ? 'NEURAL ACTIVITY DETECTED' : 'STANDBY MODE'}
              </span>
            </div>
          </div>
          
          <p 
            className="text-sm mt-2"
            style={{
              fontFamily: brandConfig.typography.fontPrimary,
              color: brandConfig.colors.textSecondary
            }}
          >
            {template.workflow.dataFlow.length} synaptic pathways • {template.workflow.expectedDuration} processing cycle
          </p>
        </div>
      )}

      {/* Neural agents container with unified coordinate system */}
      <div 
        className="agents-container relative z-10"
        style={{
          transform: `translate(${viewState.panX}px, ${viewState.panY}px) scale(${viewState.zoom})`
        }}
      >
        {/* SVG Neural Network - now inside transformed container for perfect alignment */}
        <svg 
          ref={svgRef}
          className="absolute pointer-events-none"
          style={{ 
            zIndex: 1,
            left: 0,
            top: 0,
            width: `${canvasWidth}px`,
            height: `${canvasHeight}px`
          }}
          viewBox={`0 0 ${canvasWidth} ${canvasHeight}`}
        >
          <defs>
            {/* Enhanced gradient definitions */}
            <radialGradient id="synapticGlow" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor={brandConfig.colors.synapticGreen} stopOpacity="0.8" />
              <stop offset="70%" stopColor={brandConfig.colors.electricBlue} stopOpacity="0.4" />
              <stop offset="100%" stopColor="transparent" stopOpacity="0" />
            </radialGradient>
            
            {/* Dynamic agent-specific pathway gradients */}
            {connections.map((connection) => {
              const sourceColor = getAgentColor(connection.from);
              const targetColor = getAgentColor(connection.to);
              const gradientId = `pathway-${connection.from}-${connection.to}`;
              
              console.log(`Creating gradient ${gradientId}: ${sourceColor} -> ${targetColor}`);
              
              return (
                <linearGradient key={gradientId} id={gradientId} x1="0%" y1="0%" x2="100%" y2="0%">
                  <stop offset="0%" stopColor={sourceColor} stopOpacity="0.9" />
                  <stop offset="30%" stopColor={sourceColor} stopOpacity="0.8" />
                  <stop offset="70%" stopColor={targetColor} stopOpacity="0.8" />
                  <stop offset="100%" stopColor={targetColor} stopOpacity="0.9" />
                </linearGradient>
              );
            })}

            {/* Dynamic agent-specific arrow markers */}
            {connections.map((connection) => {
              const sourceColor = getAgentColor(connection.from);
              const markerId = `arrow-${connection.from}-${connection.to}`;
              
              return (
                <marker 
                  key={markerId}
                  id={markerId}
                  markerWidth="12" 
                  markerHeight="8" 
                  refX="10" 
                  refY="4" 
                  orient="auto"
                  markerUnits="strokeWidth"
                >
                  <path 
                    d="M0,0 L0,8 L12,4 z" 
                    fill={sourceColor}
                    opacity="0.9"
                    style={{
                      filter: `drop-shadow(0 0 4px ${sourceColor}60)`
                    }}
                  />
                </marker>
              );
            })}

            {/* Signal glow filter */}
            <filter id="signalGlow" x="-50%" y="-50%" width="200%" height="200%">
              <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
              <feMerge> 
                <feMergeNode in="coloredBlur"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>

          {/* Neural pathways with agent-specific colors */}
          {connections.map((connection, index) => {
            const pathId = `${connection.from}-${connection.to}`;
            const pathData = getNeuralPath(connection.from, connection.to, connection);
            const strokeWidth = 2 + (connection.strength || 0.5) * 4;
            const gradientId = `pathway-${connection.from}-${connection.to}`;
            const arrowId = `arrow-${connection.from}-${connection.to}`;
            const sourceColor = getAgentColor(connection.from);
            
            return (
              <g key={pathId}>
                {/* Background glow path */}
                <path
                  d={pathData}
                  stroke={`url(#${gradientId})`}
                  strokeWidth={strokeWidth + 6}
                  fill="none"
                  opacity="0.2"
                  style={{
                    filter: 'blur(3px)'
                  }}
                />
                
                {/* Main neural pathway */}
                <path
                  data-connection={pathId}
                  d={pathData}
                  stroke={`url(#${gradientId})`}
                  strokeWidth={strokeWidth}
                  fill="none"
                  markerEnd={`url(#${arrowId})`}
                  style={{
                    filter: `drop-shadow(0 0 8px ${sourceColor}40)`,
                    animation: connection.animated ? 'neural-flow 4s ease-in-out infinite' : 'none',
                    animationDelay: `${index * 0.7}s`
                  }}
                />
                
                {/* Connection strength indicator */}
                {(connection.strength || 0) > 0.7 && (
                  <path
                    d={pathData}
                    stroke={sourceColor}
                    strokeWidth="1"
                    fill="none"
                    opacity="0.8"
                    style={{
                      animation: 'neural-pulse 3s ease-in-out infinite',
                      animationDelay: `${index * 0.5}s`
                    }}
                  />
                )}
              </g>
            );
          })}

          {/* Neural signals with agent-specific colors */}
          {neuralSignals.map((signal) => {
            const position = getSignalPosition(signal.connectionId, signal.progress);
            const connection = connections.find(c => `${c.from}-${c.to}` === signal.connectionId);
            const signalColor = connection ? getAgentColor(connection.from) : brandConfig.colors.electricBlue;
            
            return (
              <g key={signal.id}>
                {/* Signal glow */}
                <circle
                  cx={position.x}
                  cy={position.y}
                  r={6 * signal.intensity}
                  fill={signalColor}
                  opacity="0.3"
                  style={{
                    filter: 'blur(2px)'
                  }}
                />
                
                {/* Signal core */}
                <circle
                  cx={position.x}
                  cy={position.y}
                  r={3 * signal.intensity}
                  fill={signalColor}
                  opacity="0.9"
                  style={{
                    filter: 'url(#signalGlow)'
                  }}
                />
                
                {/* Signal trail for enhanced visibility */}
                <circle
                  cx={position.x}
                  cy={position.y}
                  r={1.5 * signal.intensity}
                  fill={brandConfig.colors.pureWhite}
                  opacity="0.8"
                />
              </g>
            );
          })}
        </svg>

        {/* Agent nodes */}
        {template.agents.map((agent, index) => {
          const position = getAgentPosition(index, template.agents.length);
          
          return (
            <div
              key={agent.id}
              className="absolute transition-all duration-300"
              style={{
                left: `${position.x}px`,
                top: `${position.y}px`,
                transform: 'translate(-50%, -50%)',
                zIndex: 5
              }}
            >
              <AgentNode 
                agent={agent}
                isActive={isActive}
                size={viewState.zoom > 1.5 ? "large" : viewState.zoom < 0.7 ? "small" : "medium"}
              />
            </div>
          );
        })}
      </div>

      {/* Activity indicator */}
      {isActive && (
        <div 
          className="absolute bottom-4 left-4 flex items-center space-x-2 z-10"
          style={{
            background: `linear-gradient(135deg, 
              ${brandConfig.colors.elevatedBlack}90 0%, 
              ${brandConfig.colors.surfaceBlack}85 100%
            )`,
            backdropFilter: 'blur(20px)',
            border: `1px solid ${brandConfig.colors.synapticGreen}40`,
            borderRadius: brandConfig.layout.borderRadius,
            padding: `${brandConfig.spacing.sm} ${brandConfig.spacing.md}`
          }}
        >
          <div 
            className="w-2 h-2 rounded-full animate-pulse"
            style={{
              background: brandConfig.colors.synapticGreen,
              boxShadow: `0 0 10px ${brandConfig.colors.synapticGreen}`
            }}
          />
          <span 
            className="text-xs font-mono"
            style={{
              fontFamily: brandConfig.typography.fontCode,
              color: brandConfig.colors.synapticGreen
            }}
          >
            NEURAL SIGNALS: {neuralSignals.length} ACTIVE
          </span>
        </div>
      )}

      {/* Global neural pulse effect */}
      {isActive && (
        <div 
          className="absolute inset-0 pointer-events-none"
          style={{
            background: `radial-gradient(circle at center, ${brandConfig.colors.synapticGreen}03 0%, transparent 60%)`,
            animation: 'neural-global-pulse 4s ease-in-out infinite'
          }}
        />
      )}
    </div>
  );
};