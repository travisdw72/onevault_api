import { useState, useEffect, useRef, useCallback } from 'react';
import { brandConfig } from '../config/brandConfig';

interface Particle {
  id: string;
  x: number;
  y: number;
  vx: number;
  vy: number;
  size: number;
  color: string;
  opacity: number;
  connectionIntensity: number;
  type: 'data' | 'processing' | 'connection' | 'neural';
}

interface Connection {
  particle1: Particle;
  particle2: Particle;
  distance: number;
  opacity: number;
  color: string;
}

interface ParticleConfig {
  particleCount: number;
  connectionDistance: number;
  animationSpeed: number;
  enableConnections: boolean;
  enableInteractivity: boolean;
  colorPalette: string[];
  maxFPS: number;
}

export const useParticles = (
  canvasRef: React.RefObject<HTMLCanvasElement | null>,
  config: Partial<ParticleConfig> = {}
) => {
  // 🎛️ Configuration with defaults
  const fullConfig: ParticleConfig = {
    particleCount: config.particleCount || brandConfig.effects.particleCount,
    connectionDistance: config.connectionDistance || brandConfig.effects.connectionDistance,
    animationSpeed: config.animationSpeed || brandConfig.effects.animationSpeed,
    enableConnections: config.enableConnections !== false,
    enableInteractivity: config.enableInteractivity !== false,
    colorPalette: config.colorPalette || [
      brandConfig.colors.electricBlue,
      brandConfig.colors.neuralPurple,
      brandConfig.colors.synapticGreen,
      brandConfig.colors.neuralPink
    ],
    maxFPS: config.maxFPS || 60
  };

  const [particles, setParticles] = useState<Particle[]>([]);
  const [connections, setConnections] = useState<Connection[]>([]);
  const [isAnimating, setIsAnimating] = useState(false);
  const [mousePosition, setMousePosition] = useState({ x: 0, y: 0 });
  const [canvasDimensions, setCanvasDimensions] = useState({ width: 0, height: 0 });

  const animationIdRef = useRef<number>();
  const lastFrameTimeRef = useRef<number>(0);
  const fpsThrottleRef = useRef<number>(1000 / fullConfig.maxFPS);

  // 🎨 Initialize particles
  const initializeParticles = useCallback((width: number, height: number): Particle[] => {
    const newParticles: Particle[] = [];
    const particleTypes: Particle['type'][] = ['data', 'processing', 'connection', 'neural'];

    for (let i = 0; i < fullConfig.particleCount; i++) {
      const type = particleTypes[Math.floor(Math.random() * particleTypes.length)];
      const colorIndex = Math.floor(Math.random() * fullConfig.colorPalette.length);
      
      newParticles.push({
        id: `particle_${i}_${Date.now()}`,
        x: Math.random() * width,
        y: Math.random() * height,
        vx: (Math.random() - 0.5) * fullConfig.animationSpeed,
        vy: (Math.random() - 0.5) * fullConfig.animationSpeed,
        size: Math.random() * 3 + 1,
        color: fullConfig.colorPalette[colorIndex],
        opacity: Math.random() * 0.8 + 0.2,
        connectionIntensity: Math.random(),
        type
      });
    }

    return newParticles;
  }, [fullConfig.particleCount, fullConfig.animationSpeed, fullConfig.colorPalette]);

  // 🔗 Calculate connections between particles
  const calculateConnections = useCallback((particles: Particle[]): Connection[] => {
    if (!fullConfig.enableConnections) return [];

    const connections: Connection[] = [];
    const maxConnections = brandConfig.effects.maxVisibleParticles;

    for (let i = 0; i < particles.length && connections.length < maxConnections; i++) {
      for (let j = i + 1; j < particles.length && connections.length < maxConnections; j++) {
        const particle1 = particles[i];
        const particle2 = particles[j];
        
        const dx = particle1.x - particle2.x;
        const dy = particle1.y - particle2.y;
        const distance = Math.sqrt(dx * dx + dy * dy);

        if (distance < fullConfig.connectionDistance) {
          const opacity = 1 - (distance / fullConfig.connectionDistance);
          
          connections.push({
            particle1,
            particle2,
            distance,
            opacity: opacity * 0.5,
            color: particle1.color
          });
        }
      }
    }

    return connections;
  }, [fullConfig.enableConnections, fullConfig.connectionDistance]);

  // ⚡ Update particle positions
  const updateParticles = useCallback((
    particles: Particle[], 
    deltaTime: number,
    width: number,
    height: number,
    mouseX: number,
    mouseY: number
  ): Particle[] => {
    return particles.map(particle => {
      let newX = particle.x + particle.vx * deltaTime;
      let newY = particle.y + particle.vy * deltaTime;
      let newVx = particle.vx;
      let newVy = particle.vy;

      // Boundary collision
      if (newX <= 0 || newX >= width) {
        newVx = -newVx;
        newX = Math.max(0, Math.min(width, newX));
      }
      if (newY <= 0 || newY >= height) {
        newVy = -newVy;
        newY = Math.max(0, Math.min(height, newY));
      }

      // Mouse interaction
      if (fullConfig.enableInteractivity) {
        const dx = mouseX - newX;
        const dy = mouseY - newY;
        const distance = Math.sqrt(dx * dx + dy * dy);
        const interactionRadius = 100;

        if (distance < interactionRadius) {
          const force = (interactionRadius - distance) / interactionRadius;
          const angle = Math.atan2(dy, dx);
          newVx -= Math.cos(angle) * force * 0.5;
          newVy -= Math.sin(angle) * force * 0.5;
        }
      }

      // Add some randomness for organic movement
      newVx += (Math.random() - 0.5) * 0.01;
      newVy += (Math.random() - 0.5) * 0.01;

      // Velocity damping
      newVx *= 0.999;
      newVy *= 0.999;

      // Ensure minimum velocity
      const minVelocity = 0.1;
      if (Math.abs(newVx) < minVelocity) newVx = Math.random() > 0.5 ? minVelocity : -minVelocity;
      if (Math.abs(newVy) < minVelocity) newVy = Math.random() > 0.5 ? minVelocity : -minVelocity;

      return {
        ...particle,
        x: newX,
        y: newY,
        vx: newVx,
        vy: newVy,
        opacity: Math.sin(Date.now() * 0.001 + particle.id.length) * 0.3 + 0.7
      };
    });
  }, [fullConfig.enableInteractivity]);

  // 🎨 Render particles and connections
  const render = useCallback((
    ctx: CanvasRenderingContext2D,
    particles: Particle[],
    connections: Connection[]
  ) => {
    // Clear canvas with slight trail effect for smoother animation
    ctx.fillStyle = 'rgba(10, 10, 10, 0.1)';
    ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);

    // Render connections
    ctx.lineWidth = 1;
    connections.forEach(connection => {
      ctx.strokeStyle = `${connection.color}${Math.floor(connection.opacity * 255).toString(16).padStart(2, '0')}`;
      ctx.beginPath();
      ctx.moveTo(connection.particle1.x, connection.particle1.y);
      ctx.lineTo(connection.particle2.x, connection.particle2.y);
      ctx.stroke();
    });

    // Render particles
    particles.forEach(particle => {
      ctx.fillStyle = `${particle.color}${Math.floor(particle.opacity * 255).toString(16).padStart(2, '0')}`;
      ctx.beginPath();
      ctx.arc(particle.x, particle.y, particle.size, 0, Math.PI * 2);
      ctx.fill();

      // Add glow effect for neural particles
      if (particle.type === 'neural') {
        ctx.shadowBlur = 10;
        ctx.shadowColor = particle.color;
        ctx.fill();
        ctx.shadowBlur = 0;
      }
    });
  }, []);

  // 🔄 Animation loop
  const animate = useCallback((currentTime: number) => {
    if (!canvasRef.current) return;

    const ctx = canvasRef.current.getContext('2d');
    if (!ctx) return;

    const deltaTime = currentTime - lastFrameTimeRef.current;

    // FPS throttling
    if (deltaTime >= fpsThrottleRef.current) {
      const { width, height } = canvasRef.current;

      setParticles(prevParticles => {
        const updatedParticles = updateParticles(
          prevParticles,
          deltaTime * 0.01,
          width,
          height,
          mousePosition.x,
          mousePosition.y
        );

        const newConnections = calculateConnections(updatedParticles);
        setConnections(newConnections);

        render(ctx, updatedParticles, newConnections);

        return updatedParticles;
      });

      lastFrameTimeRef.current = currentTime;
    }

    if (isAnimating) {
      animationIdRef.current = requestAnimationFrame(animate);
    }
  }, [
    canvasRef,
    isAnimating,
    mousePosition,
    updateParticles,
    calculateConnections,
    render
  ]);

  // 🚀 Start animation
  const startAnimation = useCallback(() => {
    if (!isAnimating) {
      setIsAnimating(true);
    }
  }, [isAnimating]);

  // 🛑 Stop animation
  const stopAnimation = useCallback(() => {
    setIsAnimating(false);
    if (animationIdRef.current) {
      cancelAnimationFrame(animationIdRef.current);
    }
  }, []);

  // 🎛️ Update particle count
  const updateParticleCount = useCallback((count: number) => {
    if (!canvasRef.current) return;
    
    const { width, height } = canvasRef.current;
    const newParticles = initializeParticles(width, height).slice(0, count);
    setParticles(newParticles);
  }, [canvasRef, initializeParticles]);

  // 🎨 Change color palette
  const updateColorPalette = useCallback((colors: string[]) => {
    setParticles(prevParticles => 
      prevParticles.map(particle => ({
        ...particle,
        color: colors[Math.floor(Math.random() * colors.length)]
      }))
    );
  }, []);

  // 📱 Handle mouse movement
  const handleMouseMove = useCallback((event: MouseEvent) => {
    if (!canvasRef.current) return;
    
    const rect = canvasRef.current.getBoundingClientRect();
    setMousePosition({
      x: event.clientX - rect.left,
      y: event.clientY - rect.top
    });
  }, [canvasRef]);

  // 📐 Handle canvas resize
  const handleResize = useCallback(() => {
    if (!canvasRef.current) return;

    const canvas = canvasRef.current;
    const parent = canvas.parentElement;
    
    if (parent) {
      canvas.width = parent.clientWidth;
      canvas.height = parent.clientHeight;
      
      setCanvasDimensions({
        width: canvas.width,
        height: canvas.height
      });

      // Reinitialize particles for new dimensions
      const newParticles = initializeParticles(canvas.width, canvas.height);
      setParticles(newParticles);
    }
  }, [canvasRef, initializeParticles]);

  // 🎯 Initialize and cleanup
  useEffect(() => {
    if (!canvasRef.current) return;

    handleResize();
    
    // Add event listeners
    window.addEventListener('resize', handleResize);
    if (fullConfig.enableInteractivity) {
      canvasRef.current.addEventListener('mousemove', handleMouseMove);
    }

    return () => {
      window.removeEventListener('resize', handleResize);
      if (canvasRef.current) {
        canvasRef.current.removeEventListener('mousemove', handleMouseMove);
      }
    };
  }, [canvasRef, handleResize, handleMouseMove, fullConfig.enableInteractivity]);

  // 🔄 Start/stop animation based on isAnimating state
  useEffect(() => {
    if (isAnimating) {
      animationIdRef.current = requestAnimationFrame(animate);
    } else if (animationIdRef.current) {
      cancelAnimationFrame(animationIdRef.current);
    }

    return () => {
      if (animationIdRef.current) {
        cancelAnimationFrame(animationIdRef.current);
      }
    };
  }, [isAnimating, animate]);

  return {
    // State
    particles,
    connections,
    isAnimating,
    mousePosition,
    canvasDimensions,
    
    // Controls
    startAnimation,
    stopAnimation,
    updateParticleCount,
    updateColorPalette,
    
    // Config
    config: fullConfig,
    
    // Stats
    particleCount: particles.length,
    connectionCount: connections.length,
    fps: Math.round(1000 / fpsThrottleRef.current)
  };
}; 