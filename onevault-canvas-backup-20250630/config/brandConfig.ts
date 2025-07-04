export const brandConfig = {
  // 🎨 Neural Network Color Palette
  colors: {
    // Canvas backgrounds
    trueBlack: '#0a0a0a',
    elevatedBlack: '#141414', 
    surfaceBlack: '#1a1a1a',
    neuralGray: '#2d2d2d',
    connectionGray: '#4a5568',
    
    // Primary neural colors
    synapticGreen: '#00ff88',
    neuralPurple: '#b366ff', 
    electricBlue: '#00d9ff',
    neuralPink: '#ff0080',
    dataLime: '#95e559',
    activeGold: '#ffd700',
    
    // Semantic node colors
    quantumTeal: '#4ecdc4',
    coralDecision: '#ff6b6b',
    fusionOrange: '#ff8c42',
    criticalRed: '#ff3366',
    alertAmber: '#ffaa00',
    
    // Text colors
    pureWhite: '#ffffff',
    textSecondary: '#a0a0a0',
    textMuted: '#4a5568'
  },

  // 📝 Typography System
  typography: {
    // Font families
    fontPrimary: "'IBM Plex Sans', sans-serif",
    fontCode: "'JetBrains Mono', monospace", 
    fontDisplay: "'Space Grotesk', sans-serif",
    fontAccent: "'Cal Sans', display",
    
    // Font sizes (zoom responsive)
    fontSizeNano: '10px',
    fontSizeMicro: '11px', 
    fontSizeXs: '12px',
    fontSizeSm: '13px',
    fontSizeBase: '14px',
    fontSizeLg: '16px',
    fontSizeXl: '18px',
    fontSize2xl: '24px',
    fontSize3xl: '32px',
    fontSize4xl: '48px',
    fontSize5xl: '64px',
    
    // Font weights
    weightLight: 300,
    weightNormal: 400,
    weightMedium: 500,
    weightSemibold: 600,
    weightBold: 700,
    
    // Line heights
    lineHeightNone: 1,
    lineHeightTight: 1.1,
    lineHeightSnug: 1.2,
    lineHeightNormal: 1.4,
    lineHeightRelaxed: 1.5,
    lineHeightLoose: 1.6
  },

  // 📏 Spacing System
  spacing: {
    xs: '0.25rem',
    sm: '0.5rem', 
    md: '1rem',
    lg: '1.5rem',
    xl: '2rem',
    '2xl': '3rem',
    '3xl': '4rem',
    '4xl': '6rem',
    '5xl': '8rem'
  },

  // 🏗️ Layout Properties
  layout: {
    borderRadius: '8px',
    borderRadiusLg: '12px',
    borderRadiusXl: '16px',
    maxWidth: '1200px',
    maxWidthWide: '1440px',
    zIndexDropdown: 1000,
    zIndexSticky: 1020,
    zIndexFixed: 1030,
    zIndexModal: 1040,
    zIndexPopover: 1050,
    zIndexTooltip: 1060
  },

  // ⚡ Animation Properties
  animations: {
    // Durations
    durationFast: '150ms',
    durationNormal: '300ms', 
    durationSlow: '500ms',
    durationXSlow: '1000ms',
    
    // Easings
    easeOut: 'cubic-bezier(0, 0, 0.2, 1)',
    easeIn: 'cubic-bezier(0.4, 0, 1, 1)',
    easeInOut: 'cubic-bezier(0.4, 0, 0.2, 1)',
    
    // Neural effects
    pulseGlow: 'pulse 2s ease-in-out infinite',
    dataFlow: 'dataFlow 3s linear infinite',
    neuralThinking: 'neuralThinking 1.5s ease-in-out infinite',
    particleOrbit: 'particleOrbit 4s linear infinite'
  },

  // 🎛️ Breakpoints
  breakpoints: {
    mobile: '320px',
    tablet: '768px',
    desktop: '1024px',
    ultrawide: '1440px'
  },

  // 🌟 Effects Configuration
  effects: {
    glowIntensity: 0.5,
    particleCount: 100,
    connectionDistance: 150,
    animationSpeed: 0.5,
    renderThrottle: 16, // 60fps
    maxVisibleParticles: 200
  }
};

// Utility function to get color with opacity
export const getColorWithOpacity = (colorKey: keyof typeof brandConfig.colors, opacity: number): string => {
  const color = brandConfig.colors[colorKey];
  // Convert hex to rgba
  const hex = color.replace('#', '');
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${opacity})`;
}; 