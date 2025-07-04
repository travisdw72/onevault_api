import React, { useState, useRef, useCallback, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { templateConfig } from '../config/templateConfig';
import { brandConfig } from '../config/brandConfig';
import { WorkflowCanvas } from '../components/templates/WorkflowCanvas';
import { AnthropicService } from '../services/anthropicService';
import type { PhotoAnalysisResponse, CompilationResponse } from '../services/anthropicService';

interface WorkflowStage {
  id: string;
  name: string;
  status: 'pending' | 'active' | 'completed' | 'error';
  progress: number;
  results?: any;
}

interface CapturedPhoto {
  id: string;
  blob: Blob;
  dataUrl: string;
  timestamp: Date;
  analysis?: PhotoAnalysisResponse;
}

export const HorseHealthWorkflow: React.FC = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  
  // Workflow state
  const [isWorkflowActive, setIsWorkflowActive] = useState(false);
  const [currentStage, setCurrentStage] = useState(0);
  const [capturedPhotos, setCapturedPhotos] = useState<CapturedPhoto[]>([]);
  const [sessionId] = useState(() => `horse_health_${Date.now()}`);
  const [finalReport, setFinalReport] = useState<CompilationResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Camera state
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [cameraPermission, setCameraPermission] = useState<'granted' | 'denied' | 'prompt'>('prompt');

  // Workflow stages
  const [stages, setStages] = useState<WorkflowStage[]>([
    { id: 'setup', name: 'Camera Setup', status: 'pending', progress: 0 },
    { id: 'capture', name: 'Photo Capture', status: 'pending', progress: 0 },
    { id: 'analysis', name: 'AI Analysis', status: 'pending', progress: 0 },
    { id: 'compilation', name: 'Report Generation', status: 'pending', progress: 0 },
    { id: 'results', name: 'Results', status: 'pending', progress: 0 }
  ]);

  // Get template configuration
  const template = templateConfig.templates.find(t => t.id === 'horse_health_analyzer');
  if (!template) {
    return <div>Template not found</div>;
  }

  // Initialize Anthropic service
  const anthropicService = React.useMemo(() => {
    const apiKey = import.meta.env.VITE_ANTHROPIC_API_KEY;
    if (!apiKey) {
      setError('Anthropic API key not configured. Please set VITE_ANTHROPIC_API_KEY.');
      return null;
    }
    return new AnthropicService({ apiKey });
  }, []);

  // Request camera permission
  const requestCameraAccess = async () => {
    try {
      const mediaStream = await navigator.mediaDevices.getUserMedia({ 
        video: { width: 1280, height: 720 }
      });
      setStream(mediaStream);
      setCameraPermission('granted');
      
      if (videoRef.current) {
        videoRef.current.srcObject = mediaStream;
      }

      updateStageStatus('setup', 'completed', 100);
      setCurrentStage(1);
    } catch (err) {
      console.error('Camera access denied:', err);
      setCameraPermission('denied');
      setError('Camera access is required for horse health analysis');
    }
  };

  // Update stage status
  const updateStageStatus = (stageId: string, status: WorkflowStage['status'], progress: number, results?: any) => {
    setStages(prev => prev.map(stage => 
      stage.id === stageId 
        ? { ...stage, status, progress, results }
        : stage
    ));
  };

  // Capture single photo
  const capturePhoto = useCallback(async (): Promise<CapturedPhoto | null> => {
    if (!videoRef.current || !canvasRef.current) return null;

    const video = videoRef.current;
    const canvas = canvasRef.current;
    const context = canvas.getContext('2d');

    if (!context) return null;

    // Set canvas dimensions to match video
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;

    // Draw current frame to canvas
    context.drawImage(video, 0, 0, canvas.width, canvas.height);

    // Convert to blob
    return new Promise((resolve) => {
      canvas.toBlob((blob) => {
        if (!blob) {
          resolve(null);
          return;
        }

        const dataUrl = canvas.toDataURL('image/jpeg', 0.8);
        const photo: CapturedPhoto = {
          id: `photo_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
          blob,
          dataUrl,
          timestamp: new Date()
        };

        resolve(photo);
      }, 'image/jpeg', 0.8);
    });
  }, []);

  // Start automated photo capture sequence
  const startPhotoCapture = async () => {
    if (!anthropicService) {
      setError('AI service not available');
      return;
    }

    setIsWorkflowActive(true);
    updateStageStatus('capture', 'active', 0);
    setCurrentStage(2);

    const photos: CapturedPhoto[] = [];
    const totalPhotos = 10;
    const intervalMs = 6000; // 6 seconds

    for (let i = 0; i < totalPhotos; i++) {
      try {
        // Capture photo
        const photo = await capturePhoto();
        if (!photo) {
          throw new Error('Failed to capture photo');
        }

        photos.push(photo);
        setCapturedPhotos([...photos]);

        // Update progress
        const progress = ((i + 1) / totalPhotos) * 100;
        updateStageStatus('capture', 'active', progress);

        // Wait before next capture (except for last photo)
        if (i < totalPhotos - 1) {
          await new Promise(resolve => setTimeout(resolve, intervalMs));
        }
      } catch (err) {
        console.error('Photo capture failed:', err);
        setError(`Failed to capture photo ${i + 1}`);
        return;
      }
    }

    // Capture complete
    updateStageStatus('capture', 'completed', 100);
    setCapturedPhotos(photos);

    // Start AI analysis
    await startAnalysis(photos);
  };

  // Analyze photos with AI
  const startAnalysis = async (photos: CapturedPhoto[]) => {
    if (!anthropicService) return;

    updateStageStatus('analysis', 'active', 0);
    setCurrentStage(3);

    const analyzedPhotos: CapturedPhoto[] = [];

    for (let i = 0; i < photos.length; i++) {
      try {
        const photo = photos[i];
        
        // Convert blob to base64
        const base64Data = await blobToBase64(photo.blob);
        const base64 = base64Data.split(',')[1]; // Remove data:image/jpeg;base64, prefix

        // Analyze with Anthropic
        const analysis = await anthropicService.analyzeHorsePhoto({
          imageData: base64,
          imageType: 'image/jpeg',
          photoIndex: i + 1,
          sessionId
        });

        const analyzedPhoto = { ...photo, analysis };
        analyzedPhotos.push(analyzedPhoto);

        // Update progress
        const progress = ((i + 1) / photos.length) * 100;
        updateStageStatus('analysis', 'active', progress);

      } catch (err) {
        console.error(`Analysis failed for photo ${i + 1}:`, err);
        // Continue with other photos even if one fails
        analyzedPhotos.push(photos[i]);
      }
    }

    // Analysis complete
    updateStageStatus('analysis', 'completed', 100);
    setCapturedPhotos(analyzedPhotos);

    // Generate final report
    await generateFinalReport(analyzedPhotos);
  };

  // Generate final compilation report
  const generateFinalReport = async (photos: CapturedPhoto[]) => {
    if (!anthropicService) return;

    updateStageStatus('compilation', 'active', 0);
    setCurrentStage(4);

    try {
      const photoAnalyses = photos
        .filter(photo => photo.analysis)
        .map(photo => photo.analysis!);

      if (photoAnalyses.length === 0) {
        throw new Error('No successful analyses to compile');
      }

      const compilation = await anthropicService.compileHealthAssessment({
        sessionId,
        photoAnalyses,
        timespan: 1, // 1 minute capture window
        additionalContext: 'Sequential photo analysis for colic detection'
      });

      setFinalReport(compilation);
      updateStageStatus('compilation', 'completed', 100);
      updateStageStatus('results', 'completed', 100);
      setCurrentStage(5);

    } catch (err) {
      console.error('Report compilation failed:', err);
      setError('Failed to generate final report');
      updateStageStatus('compilation', 'error', 0);
    }

    setIsWorkflowActive(false);
  };

  // Helper function to convert blob to base64
  const blobToBase64 = (blob: Blob): Promise<string> => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  };

  // Cleanup camera stream
  useEffect(() => {
    return () => {
      if (stream) {
        stream.getTracks().forEach(track => track.stop());
      }
    };
  }, [stream]);

  return (
    <div className="horse-health-workflow min-h-screen" style={{ background: brandConfig.colors.trueBlack }}>
      {/* Header */}
      <div 
        className="workflow-header"
        style={{
          background: `linear-gradient(135deg, 
            ${brandConfig.colors.elevatedBlack}95 0%, 
            ${brandConfig.colors.surfaceBlack}90 100%
          )`,
          border: `1px solid ${brandConfig.colors.neuralGray}30`,
          padding: brandConfig.spacing.xl,
          marginBottom: brandConfig.spacing.lg
        }}
      >
        <div className="max-w-6xl mx-auto">
          <div className="flex items-center justify-between mb-4">
            <button
              onClick={() => navigate('/gallery')}
              className="px-4 py-2 rounded-lg font-medium transition-all duration-300 hover:scale-105"
              style={{
                background: `linear-gradient(135deg, ${brandConfig.colors.neuralGray}, ${brandConfig.colors.connectionGray})`,
                color: brandConfig.colors.pureWhite,
                border: 'none',
                fontFamily: brandConfig.typography.fontPrimary
              }}
            >
              ← Back to Gallery
            </button>

            <div className="flex items-center space-x-3">
              <div 
                className="w-3 h-3 rounded-full"
                style={{
                  background: isWorkflowActive ? brandConfig.colors.synapticGreen : brandConfig.colors.neuralGray,
                  animation: isWorkflowActive ? 'pulse 2s ease-in-out infinite' : 'none'
                }}
              />
              <span 
                className="font-mono text-sm"
                style={{
                  color: isWorkflowActive ? brandConfig.colors.synapticGreen : brandConfig.colors.textMuted,
                  fontFamily: brandConfig.typography.fontCode
                }}
              >
                {isWorkflowActive ? 'WORKFLOW ACTIVE' : 'READY'}
              </span>
            </div>
          </div>

          <h1 
            className="text-4xl font-bold mb-2"
            style={{
              fontFamily: brandConfig.typography.fontDisplay,
              color: brandConfig.colors.pureWhite
            }}
          >
            🐎 {template.name}
          </h1>
          
          <p 
            className="text-lg"
            style={{
              fontFamily: brandConfig.typography.fontPrimary,
              color: brandConfig.colors.textSecondary
            }}
          >
            {template.shortDescription}
          </p>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-4 pb-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Left Column: Camera and Controls */}
          <div className="camera-section">
            {/* Camera feed */}
            <div 
              className="camera-container mb-6"
              style={{
                background: `linear-gradient(135deg, 
                  ${brandConfig.colors.elevatedBlack}95 0%, 
                  ${brandConfig.colors.surfaceBlack}90 100%
                )`,
                border: `1px solid ${brandConfig.colors.neuralGray}30`,
                borderRadius: brandConfig.layout.borderRadiusLg,
                padding: brandConfig.spacing.lg,
                position: 'relative',
                overflow: 'hidden'
              }}
            >
              <h3 
                className="text-xl font-semibold mb-4"
                style={{
                  fontFamily: brandConfig.typography.fontDisplay,
                  color: brandConfig.colors.pureWhite
                }}
              >
                📸 Camera Feed
              </h3>

              {cameraPermission === 'prompt' && (
                <div className="text-center py-8">
                  <div className="mb-4 text-6xl">📷</div>
                  <p 
                    className="mb-4"
                    style={{
                      color: brandConfig.colors.textSecondary,
                      fontFamily: brandConfig.typography.fontPrimary
                    }}
                  >
                    Camera access required for horse health analysis
                  </p>
                  <button
                    onClick={requestCameraAccess}
                    className="px-6 py-3 rounded-lg font-medium transition-all duration-300 hover:scale-105"
                    style={{
                      background: `linear-gradient(135deg, ${brandConfig.colors.synapticGreen}, ${brandConfig.colors.electricBlue})`,
                      color: brandConfig.colors.trueBlack,
                      border: 'none',
                      fontFamily: brandConfig.typography.fontPrimary
                    }}
                  >
                    Enable Camera
                  </button>
                </div>
              )}

              {cameraPermission === 'denied' && (
                <div className="text-center py-8">
                  <div className="mb-4 text-6xl">❌</div>
                  <p 
                    className="text-red-400"
                    style={{
                      fontFamily: brandConfig.typography.fontPrimary
                    }}
                  >
                    Camera access denied. Please enable camera permissions and refresh the page.
                  </p>
                </div>
              )}

              {cameraPermission === 'granted' && (
                <div className="camera-display">
                  <video
                    ref={videoRef}
                    autoPlay
                    playsInline
                    muted
                    className="w-full rounded-lg"
                    style={{
                      background: brandConfig.colors.surfaceBlack,
                      maxHeight: '300px',
                      objectFit: 'cover'
                    }}
                  />
                  <canvas
                    ref={canvasRef}
                    style={{ display: 'none' }}
                  />
                </div>
              )}
            </div>

            {/* Controls */}
            <div 
              className="controls-container"
              style={{
                background: `linear-gradient(135deg, 
                  ${brandConfig.colors.elevatedBlack}95 0%, 
                  ${brandConfig.colors.surfaceBlack}90 100%
                )`,
                border: `1px solid ${brandConfig.colors.neuralGray}30`,
                borderRadius: brandConfig.layout.borderRadiusLg,
                padding: brandConfig.spacing.lg
              }}
            >
              <h3 
                className="text-xl font-semibold mb-4"
                style={{
                  fontFamily: brandConfig.typography.fontDisplay,
                  color: brandConfig.colors.pureWhite
                }}
              >
                🎛️ Workflow Controls
              </h3>

              <button
                onClick={startPhotoCapture}
                disabled={cameraPermission !== 'granted' || isWorkflowActive}
                className="w-full px-6 py-4 rounded-lg font-medium transition-all duration-300 hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                style={{
                  background: isWorkflowActive
                    ? `${brandConfig.colors.neuralGray}40`
                    : `linear-gradient(135deg, ${brandConfig.colors.synapticGreen}, ${brandConfig.colors.electricBlue})`,
                  color: isWorkflowActive ? brandConfig.colors.textMuted : brandConfig.colors.trueBlack,
                  border: 'none',
                  fontFamily: brandConfig.typography.fontPrimary,
                  fontSize: brandConfig.typography.fontSizeLg
                }}
              >
                {isWorkflowActive ? '🔄 Analysis in Progress...' : '🚀 Start Health Analysis'}
              </button>

              {error && (
                <div 
                  className="mt-4 p-3 rounded-lg"
                  style={{
                    background: `${brandConfig.colors.criticalRed}20`,
                    border: `1px solid ${brandConfig.colors.criticalRed}40`,
                    color: brandConfig.colors.criticalRed
                  }}
                >
                  ⚠️ {error}
                </div>
              )}
            </div>
          </div>

          {/* Right Column: Workflow Visualization and Progress */}
          <div className="workflow-section">
            {/* Workflow Canvas */}
            <div className="mb-6">
              <WorkflowCanvas 
                template={template}
                isActive={isWorkflowActive}
              />
            </div>

            {/* Progress Stages */}
            <div 
              className="stages-container"
              style={{
                background: `linear-gradient(135deg, 
                  ${brandConfig.colors.elevatedBlack}95 0%, 
                  ${brandConfig.colors.surfaceBlack}90 100%
                )`,
                border: `1px solid ${brandConfig.colors.neuralGray}30`,
                borderRadius: brandConfig.layout.borderRadiusLg,
                padding: brandConfig.spacing.lg
              }}
            >
              <h3 
                className="text-xl font-semibold mb-4"
                style={{
                  fontFamily: brandConfig.typography.fontDisplay,
                  color: brandConfig.colors.pureWhite
                }}
              >
                📊 Workflow Progress
              </h3>

              <div className="space-y-3">
                {stages.map((stage, index) => (
                  <div key={stage.id} className="stage-item">
                    <div className="flex items-center justify-between mb-1">
                      <div className="flex items-center space-x-3">
                        <div 
                          className="w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold"
                          style={{
                            background: stage.status === 'completed' 
                              ? brandConfig.colors.synapticGreen
                              : stage.status === 'active' 
                              ? brandConfig.colors.electricBlue
                              : stage.status === 'error'
                              ? brandConfig.colors.criticalRed
                              : `${brandConfig.colors.neuralGray}40`,
                            color: stage.status === 'pending' ? brandConfig.colors.textMuted : brandConfig.colors.trueBlack
                          }}
                        >
                          {stage.status === 'completed' ? '✓' : 
                           stage.status === 'error' ? '✗' : 
                           stage.status === 'active' ? '⟳' : index + 1}
                        </div>
                        <span 
                          className="font-medium"
                          style={{
                            color: stage.status === 'pending' ? brandConfig.colors.textMuted : brandConfig.colors.pureWhite,
                            fontFamily: brandConfig.typography.fontPrimary
                          }}
                        >
                          {stage.name}
                        </span>
                      </div>
                      <span 
                        className="text-sm font-mono"
                        style={{
                          color: brandConfig.colors.textSecondary,
                          fontFamily: brandConfig.typography.fontCode
                        }}
                      >
                        {stage.progress}%
                      </span>
                    </div>

                    {/* Progress bar */}
                    <div 
                      className="w-full h-1 rounded-full overflow-hidden"
                      style={{ background: `${brandConfig.colors.neuralGray}30` }}
                    >
                      <div 
                        className="h-full transition-all duration-500 ease-out rounded-full"
                        style={{
                          width: `${stage.progress}%`,
                          background: stage.status === 'error' 
                            ? brandConfig.colors.criticalRed
                            : `linear-gradient(90deg, ${brandConfig.colors.synapticGreen}, ${brandConfig.colors.electricBlue})`
                        }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Results Section */}
        {finalReport && (
          <div 
            className="results-section mt-8"
            style={{
              background: `linear-gradient(135deg, 
                ${brandConfig.colors.elevatedBlack}95 0%, 
                ${brandConfig.colors.surfaceBlack}90 100%
              )`,
              border: `1px solid ${brandConfig.colors.synapticGreen}40`,
              borderRadius: brandConfig.layout.borderRadiusLg,
              padding: brandConfig.spacing.xl
            }}
          >
            <h2 
              className="text-2xl font-bold mb-6"
              style={{
                fontFamily: brandConfig.typography.fontDisplay,
                color: brandConfig.colors.pureWhite
              }}
            >
              📋 Health Assessment Report
            </h2>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
              {/* Risk Score */}
              <div 
                className="risk-score-card p-4 rounded-lg"
                style={{
                  background: `${brandConfig.colors.elevatedBlack}80`,
                  border: `1px solid ${brandConfig.colors.neuralGray}30`
                }}
              >
                <h4 
                  className="text-sm font-semibold mb-2"
                  style={{
                    color: brandConfig.colors.textSecondary,
                    fontFamily: brandConfig.typography.fontCode,
                    textTransform: 'uppercase'
                  }}
                >
                  Risk Level
                </h4>
                <div 
                  className="text-2xl font-bold"
                  style={{
                    color: finalReport.finalAssessment.riskLevel === 'critical' ? brandConfig.colors.criticalRed :
                           finalReport.finalAssessment.riskLevel === 'high' ? brandConfig.colors.fusionOrange :
                           finalReport.finalAssessment.riskLevel === 'medium' ? brandConfig.colors.activeGold :
                           brandConfig.colors.synapticGreen,
                    fontFamily: brandConfig.typography.fontDisplay
                  }}
                >
                  {finalReport.finalAssessment.riskLevel.toUpperCase()}
                </div>
                <div 
                  className="text-sm mt-1"
                  style={{
                    color: brandConfig.colors.textSecondary,
                    fontFamily: brandConfig.typography.fontCode
                  }}
                >
                  Score: {finalReport.finalAssessment.overallRiskScore}/100
                </div>
              </div>

              {/* Confidence */}
              <div 
                className="confidence-card p-4 rounded-lg"
                style={{
                  background: `${brandConfig.colors.elevatedBlack}80`,
                  border: `1px solid ${brandConfig.colors.neuralGray}30`
                }}
              >
                <h4 
                  className="text-sm font-semibold mb-2"
                  style={{
                    color: brandConfig.colors.textSecondary,
                    fontFamily: brandConfig.typography.fontCode,
                    textTransform: 'uppercase'
                  }}
                >
                  Confidence
                </h4>
                <div 
                  className="text-2xl font-bold"
                  style={{
                    color: brandConfig.colors.electricBlue,
                    fontFamily: brandConfig.typography.fontDisplay
                  }}
                >
                  {Math.round(finalReport.finalAssessment.confidenceScore * 100)}%
                </div>
              </div>

              {/* Urgency */}
              <div 
                className="urgency-card p-4 rounded-lg"
                style={{
                  background: `${brandConfig.colors.elevatedBlack}80`,
                  border: `1px solid ${brandConfig.colors.neuralGray}30`
                }}
              >
                <h4 
                  className="text-sm font-semibold mb-2"
                  style={{
                    color: brandConfig.colors.textSecondary,
                    fontFamily: brandConfig.typography.fontCode,
                    textTransform: 'uppercase'
                  }}
                >
                  Veterinary Urgency
                </h4>
                <div 
                  className="text-lg font-bold"
                  style={{
                    color: finalReport.finalAssessment.veterinaryRecommendations.urgency === 'emergency' ? brandConfig.colors.criticalRed :
                           finalReport.finalAssessment.veterinaryRecommendations.urgency === 'urgent' ? brandConfig.colors.fusionOrange :
                           finalReport.finalAssessment.veterinaryRecommendations.urgency === 'soon' ? brandConfig.colors.activeGold :
                           brandConfig.colors.synapticGreen,
                    fontFamily: brandConfig.typography.fontDisplay
                  }}
                >
                  {finalReport.finalAssessment.veterinaryRecommendations.urgency.toUpperCase()}
                </div>
              </div>
            </div>

            {/* Summary */}
            <div 
              className="summary-section p-4 rounded-lg mb-6"
              style={{
                background: `${brandConfig.colors.surfaceBlack}80`,
                border: `1px solid ${brandConfig.colors.neuralGray}30`
              }}
            >
              <h4 
                className="text-lg font-semibold mb-3"
                style={{
                  color: brandConfig.colors.pureWhite,
                  fontFamily: brandConfig.typography.fontDisplay
                }}
              >
                📝 Assessment Summary
              </h4>
              <p 
                style={{
                  color: brandConfig.colors.textSecondary,
                  fontFamily: brandConfig.typography.fontPrimary,
                  lineHeight: brandConfig.typography.lineHeightRelaxed
                }}
              >
                {finalReport.finalAssessment.summary}
              </p>
            </div>

            {/* Recommendations */}
            <div 
              className="recommendations-section"
              style={{
                background: `${brandConfig.colors.surfaceBlack}80`,
                border: `1px solid ${brandConfig.colors.neuralGray}30`,
                borderRadius: brandConfig.layout.borderRadius,
                padding: brandConfig.spacing.lg
              }}
            >
              <h4 
                className="text-lg font-semibold mb-3"
                style={{
                  color: brandConfig.colors.pureWhite,
                  fontFamily: brandConfig.typography.fontDisplay
                }}
              >
                🎯 Veterinary Recommendations
              </h4>
              
              <div className="space-y-2">
                {finalReport.finalAssessment.veterinaryRecommendations.actions.map((action, index) => (
                  <div 
                    key={index}
                    className="flex items-start space-x-2"
                  >
                    <span 
                      style={{ color: brandConfig.colors.synapticGreen }}
                    >
                      •
                    </span>
                    <span 
                      style={{
                        color: brandConfig.colors.textSecondary,
                        fontFamily: brandConfig.typography.fontPrimary
                      }}
                    >
                      {action}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}; 