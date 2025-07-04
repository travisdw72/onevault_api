/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'true-black': '#0a0a0a',
        'elevated-black': '#141414',
        'surface-black': '#1a1a1a',
        'neural-gray': '#2d2d2d',
        'connection-gray': '#4a5568',
        
        'synaptic-green': '#00ff88',
        'neural-purple': '#b366ff',
        'electric-blue': '#00d9ff',
        'neural-pink': '#ff0080',
        'data-lime': '#95e559',
        'active-gold': '#ffd700',
        
        'pure-white': '#ffffff',
        'text-secondary': '#a0a0a0',
      },
      fontFamily: {
        'ibm-plex': ['IBM Plex Sans', 'sans-serif'],
        'jetbrains': ['JetBrains Mono', 'monospace'],
        'space': ['Space Grotesk', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
