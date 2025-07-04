import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Home } from './pages/Home';
import { Login } from './pages/Login';
import { DemoUserDashboard } from './pages/DemoUserDashboard';
import { TemplateGallery } from './components/templates/TemplateGallery';
import { HorseHealthWorkflow } from './pages/HorseHealthWorkflow';
import { brandConfig } from './config/brandConfig';
import './index.css'

function App() {
  return (
    <Router>
      <div 
        className="neural-app min-h-screen"
        style={{
          fontFamily: brandConfig.typography.fontPrimary,
          background: brandConfig.colors.trueBlack,
          color: brandConfig.colors.pureWhite
        }}
      >
        <Routes>
          {/* 🏠 Home/Landing Page */}
          <Route path="/" element={<Home />} />
          
          {/* 🔐 Authentication */}
          <Route path="/login" element={<Login />} />
          
          {/* 🚀 Neural Network Dashboard */}
          <Route path="/dashboard" element={<DemoUserDashboard />} />
          
          {/* 🤖 AI Template Gallery */}
          <Route path="/gallery" element={<TemplateGallery />} />
          
          {/* 🐴 Horse Health Multi-Agent Workflow */}
          <Route path="/workflows/horse-health" element={<HorseHealthWorkflow />} />
          
          {/* 🔄 Catch-all redirect */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </div>
    </Router>
  )
}

export default App
