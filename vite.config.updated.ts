import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { siteMetadataConfig } from "./src/config/siteMetadataConfig";
import * as path from "path";

// https://vitejs.dev/config/
export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  plugins: [
    react(),
    {
      name: "html-transform",
      transformIndexHtml(html) {
        return html
          .replace(/%SITE_TITLE%/g, siteMetadataConfig.title)
          .replace(/%SITE_DESCRIPTION%/g, siteMetadataConfig.description)
          .replace(/%SITE_OG_IMAGE%/g, siteMetadataConfig.ogImage)
          .replace(/%SITE_TWITTER_IMAGE%/g, siteMetadataConfig.twitterImage)
          .replace(/%SITE_THEME_COLOR%/g, siteMetadataConfig.themeColor);
      },
    },
  ],
  server: {
    host: '0.0.0.0',  // This will expose to all network interfaces
    fs: {
      // Allow serving files from parent directory
      allow: [
        // The project root
        path.resolve(__dirname),
        // The parent directory (for node_modules access)
        path.resolve(__dirname, '..')
      ]
    },
    // Development proxy to handle API requests
    proxy: {
      // Proxy for your local PHP server (keep this for other API calls)
      '/api': {
        target: 'http://localhost:80', // XAMPP Apache server
        changeOrigin: true,
        secure: false,
        configure: (proxy, _options) => {
          proxy.on('error', (err, _req, _res) => {
            console.log('proxy error', err);
          });
          proxy.on('proxyReq', (proxyReq, req, _res) => {
            console.log('Sending Request to the Target:', req.method, req.url);
          });
          proxy.on('proxyRes', (proxyRes, req, _res) => {
            console.log('Received Response from the Target:', proxyRes.statusCode, req.url);
          });
        },
      },
      // NEW: Proxy for One Vault tracking API to bypass CORS
      '/tracking': {
        target: 'https://app-wild-glade-78480567.dpl.myneon.app',
        changeOrigin: true,
        secure: true,
        rewrite: (path) => path.replace(/^\/tracking/, ''),
        configure: (proxy, _options) => {
          proxy.on('error', (err, _req, _res) => {
            console.log('🚨 TRACKING PROXY ERROR:', err);
          });
          proxy.on('proxyReq', (proxyReq, req, _res) => {
            console.log('🚀 TRACKING TO NEON:', req.method, req.url);
            // Add the API key to all requests to Neon
            proxyReq.setHeader('Authorization', `Bearer ${process.env.VITE_ONEVAULT_API_KEY || 'ovt_prod_7113cf25b40905d0adee776765aabd511f87bc6c94766b83e81e8063d00f483f'}`);
          });
          proxy.on('proxyRes', (proxyRes, req, _res) => {
            console.log('✅ NEON RESPONSE:', proxyRes.statusCode, req.url);
          });
        },
      }
    }
  },
  build: {
    rollupOptions: {
      output: {
        // Ensure video files are not chunked or processed
        assetFileNames: (assetInfo) => {
          const info = assetInfo.name?.split('.') || [];
          const extType = info[info.length - 1];
          
          // Keep video files in their original directory structure
          if (/^(mp4|webm|ogv|mov)$/i.test(extType)) {
            return `videos/[name].[ext]`;
          }
          
          // Keep images in their directory
          if (/^(png|jpe?g|svg|gif|webp|avif)$/i.test(extType)) {
            return `images/[name].[hash].[ext]`;
          }
          
          return `assets/[name].[hash].[ext]`;
        }
      }
    },
    // Increase chunk size warning limit for video files
    chunkSizeWarningLimit: 1000,
    // Don't inline video files
    assetsInlineLimit: 0
  },
  assetsInclude: ['**/*.mp4', '**/*.webm', '**/*.ogv', '**/*.mov']
}); 