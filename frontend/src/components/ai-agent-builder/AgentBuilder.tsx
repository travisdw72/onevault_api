import React, { useState, useEffect } from 'react';
import { 
  Card, 
  Button, 
  Steps, 
  Form, 
  Input, 
  Select, 
  Switch, 
  Slider, 
  notification,
  Space,
  Divider,
  Tag,
  Typography,
  Row,
  Col,
  Modal,
  Progress
} from 'antd';
import { 
  RobotOutlined,
  EyeOutlined,
  SoundOutlined,
  ApiOutlined,
  SettingOutlined,
  PlayCircleOutlined,
  SaveOutlined,
  DollarOutlined
} from '@ant-design/icons';
import { useTenant } from '@/hooks/useTenant';
import { useAIAgentBuilder } from '@/hooks/useAIAgentBuilder';
import { AIAgentTemplate, UserAgentConfig, AgentExecutionResult } from '@/interfaces/AIAgentTypes';

const { Title, Text, Paragraph } = Typography;
const { Option } = Select;
const { TextArea } = Input;

interface AgentBuilderProps {
  onAgentCreated?: (agentId: string) => void;
}

export const AgentBuilder: React.FC<AgentBuilderProps> = ({ onAgentCreated }) => {
  const { tenantId } = useTenant();
  const { 
    templates, 
    createAgent, 
    testAgent, 
    deployAgent,
    isLoading,
    isTestingAgent 
  } = useAIAgentBuilder();

  const [currentStep, setCurrentStep] = useState(0);
  const [selectedTemplate, setSelectedTemplate] = useState<AIAgentTemplate | null>(null);
  const [agentConfig, setAgentConfig] = useState<UserAgentConfig>({
    agentName: '',
    agentDescription: '',
    userConfiguration: {},
    privacySettings: {},
    alertConfiguration: {},
    costManagement: { monthlyBudget: 50 }
  });
  const [testResults, setTestResults] = useState<AgentExecutionResult | null>(null);
  const [showTestModal, setShowTestModal] = useState(false);

  // Agent template categories with icons and descriptions
  const templateCategories = [
    {
      key: 'IMAGE_AI',
      name: 'Image Analysis',
      icon: <EyeOutlined style={{ fontSize: '48px', color: '#1890ff' }} />,
      description: 'Analyze photos and images using computer vision',
      useCases: ['Horse health monitoring', 'Equipment inspection', 'Quality control']
    },
    {
      key: 'VOICE_AI', 
      name: 'Voice Analysis',
      icon: <SoundOutlined style={{ fontSize: '48px', color: '#52c41a' }} />,
      description: 'Analyze voice recordings for insights and monitoring',
      useCases: ['Senior wellness monitoring', 'Customer service analysis', 'Health tracking']
    },
    {
      key: 'SENSOR_AI',
      name: 'Sensor Data',
      icon: <ApiOutlined style={{ fontSize: '48px', color: '#faad14' }} />,
      description: 'Analyze IoT sensor data for patterns and predictions',
      useCases: ['Predictive maintenance', 'Environmental monitoring', 'Performance optimization']
    }
  ];

  const steps = [
    { title: 'Choose Template', icon: <RobotOutlined /> },
    { title: 'Configure Agent', icon: <SettingOutlined /> },
    { title: 'Test & Validate', icon: <PlayCircleOutlined /> },
    { title: 'Deploy', icon: <SaveOutlined /> }
  ];

  // Template selection component
  const TemplateSelection = () => (
    <div>
      <Title level={3}>Choose Your AI Agent Template</Title>
      <Paragraph>
        Select a template that matches your use case. You can customize it in the next step.
      </Paragraph>
      
      <Row gutter={[24, 24]}>
        {templateCategories.map(category => {
          const categoryTemplates = templates.filter(t => t.templateCategory === category.key);
          
          return (
            <Col span={8} key={category.key}>
              <Card
                hoverable
                style={{ height: '100%' }}
                bodyStyle={{ textAlign: 'center', padding: '24px' }}
              >
                {category.icon}
                <Title level={4} style={{ marginTop: '16px' }}>
                  {category.name}
                </Title>
                <Paragraph type="secondary">
                  {category.description}
                </Paragraph>
                
                <div style={{ marginBottom: '16px' }}>
                  {category.useCases.map(useCase => (
                    <Tag key={useCase} color="blue" style={{ margin: '2px' }}>
                      {useCase}
                    </Tag>
                  ))}
                </div>
                
                <Select
                  style={{ width: '100%', marginBottom: '16px' }}
                  placeholder="Select a template"
                  value={selectedTemplate?.templateName}
                  onChange={(value) => {
                    const template = templates.find(t => t.templateName === value);
                    setSelectedTemplate(template || null);
                  }}
                >
                  {categoryTemplates.map(template => (
                    <Option key={template.templateName} value={template.templateName}>
                      {template.templateName}
                      <Tag color="green" style={{ marginLeft: '8px' }}>
                        ${template.estimatedCostPerUse}
                      </Tag>
                    </Option>
                  ))}
                </Select>
                
                {selectedTemplate?.templateCategory === category.key && (
                  <Card size="small" style={{ textAlign: 'left' }}>
                    <Text strong>Selected: </Text>
                    <Text>{selectedTemplate.templateName}</Text>
                    <br />
                    <Text type="secondary">{selectedTemplate.description}</Text>
                    <div style={{ marginTop: '8px' }}>
                      <Tag color="orange">
                        {selectedTemplate.complexityLevel}
                      </Tag>
                      <Tag color="green">
                        ~${selectedTemplate.estimatedCostPerUse}/use
                      </Tag>
                    </div>
                  </Card>
                )}
              </Card>
            </Col>
          );
        })}
      </Row>
    </div>
  );

  // Agent configuration component
  const AgentConfiguration = () => {
    if (!selectedTemplate) return null;

    const renderConfigField = (key: string, schema: any) => {
      switch (schema.type) {
        case 'string':
          if (schema.enum) {
            return (
              <Select
                style={{ width: '100%' }}
                placeholder={schema.description}
                value={agentConfig.userConfiguration[key]}
                onChange={(value) => setAgentConfig(prev => ({
                  ...prev,
                  userConfiguration: { ...prev.userConfiguration, [key]: value }
                }))}
              >
                {schema.enum.map((option: string) => (
                  <Option key={option} value={option}>{option}</Option>
                ))}
              </Select>
            );
          }
          return (
            <Input
              placeholder={schema.description}
              value={agentConfig.userConfiguration[key]}
              onChange={(e) => setAgentConfig(prev => ({
                ...prev,
                userConfiguration: { ...prev.userConfiguration, [key]: e.target.value }
              }))}
            />
          );
        
        case 'number':
          return (
            <Slider
              min={schema.minimum || 0}
              max={schema.maximum || 1}
              step={0.1}
              value={agentConfig.userConfiguration[key] || schema.default || 0.5}
              onChange={(value) => setAgentConfig(prev => ({
                ...prev,
                userConfiguration: { ...prev.userConfiguration, [key]: value }
              }))}
              marks={{
                [schema.minimum || 0]: schema.minimum || 0,
                [schema.maximum || 1]: schema.maximum || 1
              }}
            />
          );
        
        case 'boolean':
          return (
            <Switch
              checked={agentConfig.userConfiguration[key] || false}
              onChange={(checked) => setAgentConfig(prev => ({
                ...prev,
                userConfiguration: { ...prev.userConfiguration, [key]: checked }
              }))}
            />
          );
        
        default:
          return (
            <Input
              placeholder={schema.description}
              value={agentConfig.userConfiguration[key]}
              onChange={(e) => setAgentConfig(prev => ({
                ...prev,
                userConfiguration: { ...prev.userConfiguration, [key]: e.target.value }
              }))}
            />
          );
      }
    };

    return (
      <div>
        <Title level={3}>Configure Your {selectedTemplate.templateName}</Title>
        
        <Row gutter={24}>
          <Col span={12}>
            <Card title="Basic Settings" style={{ marginBottom: '16px' }}>
              <Form layout="vertical">
                <Form.Item label="Agent Name" required>
                  <Input
                    placeholder="e.g., Thunder's Health Monitor"
                    value={agentConfig.agentName}
                    onChange={(e) => setAgentConfig(prev => ({ 
                      ...prev, 
                      agentName: e.target.value 
                    }))}
                  />
                </Form.Item>
                
                <Form.Item label="Description">
                  <TextArea
                    placeholder="Describe what this agent will do..."
                    value={agentConfig.agentDescription}
                    onChange={(e) => setAgentConfig(prev => ({ 
                      ...prev, 
                      agentDescription: e.target.value 
                    }))}
                    rows={3}
                  />
                </Form.Item>
              </Form>
            </Card>

            <Card title="AI Configuration">
              <Form layout="vertical">
                {selectedTemplate.configurationSchema && 
                  Object.entries(selectedTemplate.configurationSchema).map(([key, schema]: [string, any]) => (
                    <Form.Item key={key} label={key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}>
                      {renderConfigField(key, schema)}
                      {schema.description && (
                        <Text type="secondary" style={{ fontSize: '12px' }}>
                          {schema.description}
                        </Text>
                      )}
                    </Form.Item>
                  ))
                }
              </Form>
            </Card>
          </Col>

          <Col span={12}>
            <Card title="Privacy & Security" style={{ marginBottom: '16px' }}>
              <Form layout="vertical">
                <Form.Item label="Data Access">
                  <Select
                    value={agentConfig.privacySettings?.dataAccess || 'own_tenant_only'}
                    onChange={(value) => setAgentConfig(prev => ({
                      ...prev,
                      privacySettings: { ...prev.privacySettings, dataAccess: value }
                    }))}
                  >
                    <Option value="own_tenant_only">My Data Only</Option>
                    <Option value="shared_with_consent">Shared (with consent)</Option>
                    <Option value="anonymized_insights">Anonymized Insights</Option>
                  </Select>
                </Form.Item>
                
                <Form.Item label="Data Retention (days)">
                  <Slider
                    min={1}
                    max={3650}
                    value={agentConfig.privacySettings?.retentionDays || 365}
                    onChange={(value) => setAgentConfig(prev => ({
                      ...prev,
                      privacySettings: { ...prev.privacySettings, retentionDays: value }
                    }))}
                    marks={{ 1: '1 day', 30: '30 days', 365: '1 year', 3650: '10 years' }}
                  />
                </Form.Item>

                {selectedTemplate.templateCategory === 'VOICE_AI' && (
                  <Form.Item label="HIPAA Compliance">
                    <Switch
                      checked={agentConfig.privacySettings?.hipaaCompliance || false}
                      onChange={(checked) => setAgentConfig(prev => ({
                        ...prev,
                        privacySettings: { ...prev.privacySettings, hipaaCompliance: checked }
                      }))}
                    />
                    <Text type="secondary" style={{ display: 'block', marginTop: '4px' }}>
                      Enable for healthcare applications
                    </Text>
                  </Form.Item>
                )}
              </Form>
            </Card>

            <Card title={<><DollarOutlined /> Cost Management</>}>
              <Form layout="vertical">
                <Form.Item label="Monthly Budget ($)">
                  <Slider
                    min={5}
                    max={500}
                    value={agentConfig.costManagement?.monthlyBudget || 50}
                    onChange={(value) => setAgentConfig(prev => ({
                      ...prev,
                      costManagement: { ...prev.costManagement, monthlyBudget: value }
                    }))}
                    marks={{ 5: '$5', 50: '$50', 100: '$100', 500: '$500' }}
                  />
                </Form.Item>
                
                <div style={{ padding: '12px', background: '#f6f6f6', borderRadius: '6px' }}>
                  <Text type="secondary">
                    Estimated usage: ~{Math.floor((agentConfig.costManagement?.monthlyBudget || 50) / (selectedTemplate.estimatedCostPerUse || 0.05))} executions/month
                  </Text>
                </div>
              </Form>
            </Card>
          </Col>
        </Row>
      </div>
    );
  };

  // Test and validation component
  const TestValidation = () => (
    <div>
      <Title level={3}>Test Your Agent</Title>
      <Paragraph>
        Test your agent with sample data to make sure it works as expected before deploying.
      </Paragraph>

      <Card>
        <Space direction="vertical" style={{ width: '100%' }}>
          <Button
            type="primary"
            size="large"
            icon={<PlayCircleOutlined />}
            loading={isTestingAgent}
            onClick={() => setShowTestModal(true)}
          >
            Run Test
          </Button>

          {testResults && (
            <div>
              <Divider />
              <Title level={4}>Test Results</Title>
              <Row gutter={16}>
                <Col span={6}>
                  <Card size="small">
                    <div style={{ textAlign: 'center' }}>
                      <Text type="secondary">Execution Time</Text>
                      <div style={{ fontSize: '24px', fontWeight: 'bold' }}>
                        {testResults.processingTimeMs}ms
                      </div>
                    </div>
                  </Card>
                </Col>
                <Col span={6}>
                  <Card size="small">
                    <div style={{ textAlign: 'center' }}>
                      <Text type="secondary">Confidence</Text>
                      <div style={{ fontSize: '24px', fontWeight: 'bold' }}>
                        {Math.round((testResults.confidenceScore || 0) * 100)}%
                      </div>
                    </div>
                  </Card>
                </Col>
                <Col span={6}>
                  <Card size="small">
                    <div style={{ textAlign: 'center' }}>
                      <Text type="secondary">Cost</Text>
                      <div style={{ fontSize: '24px', fontWeight: 'bold' }}>
                        ${testResults.costIncurred?.toFixed(3)}
                      </div>
                    </div>
                  </Card>
                </Col>
                <Col span={6}>
                  <Card size="small">
                    <div style={{ textAlign: 'center' }}>
                      <Text type="secondary">Status</Text>
                      <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#52c41a' }}>
                        {testResults.status}
                      </div>
                    </div>
                  </Card>
                </Col>
              </Row>

              <Card title="Analysis Results" style={{ marginTop: '16px' }}>
                <pre style={{ whiteSpace: 'pre-wrap', fontSize: '12px' }}>
                  {JSON.stringify(testResults.result, null, 2)}
                </pre>
              </Card>
            </div>
          )}
        </Space>
      </Card>
    </div>
  );

  // Deploy component
  const Deploy = () => (
    <div>
      <Title level={3}>Deploy Your Agent</Title>
      <Paragraph>
        Your agent is ready to deploy! Once deployed, it will be active and ready to process requests.
      </Paragraph>

      <Card>
        <Space direction="vertical" style={{ width: '100%' }}>
          <div style={{ padding: '20px', background: '#f6f6f6', borderRadius: '8px' }}>
            <Title level={4}>{agentConfig.agentName}</Title>
            <Text type="secondary">{agentConfig.agentDescription}</Text>
            
            <Row gutter={16} style={{ marginTop: '16px' }}>
              <Col span={8}>
                <Text strong>Template:</Text>
                <div>{selectedTemplate?.templateName}</div>
              </Col>
              <Col span={8}>
                <Text strong>Monthly Budget:</Text>
                <div>${agentConfig.costManagement?.monthlyBudget}</div>
              </Col>
              <Col span={8}>
                <Text strong>Data Access:</Text>
                <div>{agentConfig.privacySettings?.dataAccess}</div>
              </Col>
            </Row>
          </div>

          <Button
            type="primary"
            size="large"
            icon={<SaveOutlined />}
            loading={isLoading}
            onClick={handleDeploy}
          >
            Deploy Agent
          </Button>
        </Space>
      </Card>
    </div>
  );

  const handleNext = () => {
    if (currentStep === 0 && !selectedTemplate) {
      notification.error({ message: 'Please select a template first' });
      return;
    }
    if (currentStep === 1 && !agentConfig.agentName) {
      notification.error({ message: 'Please provide an agent name' });
      return;
    }
    setCurrentStep(currentStep + 1);
  };

  const handlePrev = () => {
    setCurrentStep(currentStep - 1);
  };

  const handleTest = async (testData: any) => {
    if (!selectedTemplate) return;
    
    try {
      const result = await testAgent(agentConfig, testData);
      setTestResults(result);
      setShowTestModal(false);
      notification.success({ message: 'Test completed successfully!' });
    } catch (error) {
      notification.error({ message: 'Test failed', description: error.message });
    }
  };

  const handleDeploy = async () => {
    if (!selectedTemplate) return;

    try {
      const result = await createAgent(selectedTemplate.agentTemplateHk, agentConfig);
      notification.success({ 
        message: 'Agent created successfully!',
        description: `${agentConfig.agentName} is now active and ready to use.`
      });
      
      if (onAgentCreated) {
        onAgentCreated(result.agentId);
      }
    } catch (error) {
      notification.error({ message: 'Failed to create agent', description: error.message });
    }
  };

  return (
    <div style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <Title level={2}>
        <RobotOutlined /> Create Your AI Agent
      </Title>
      <Paragraph>
        Build a custom AI agent tailored to your specific needs. No coding required!
      </Paragraph>

      <Steps current={currentStep} items={steps} style={{ marginBottom: '32px' }} />

      <div style={{ minHeight: '500px' }}>
        {currentStep === 0 && <TemplateSelection />}
        {currentStep === 1 && <AgentConfiguration />}
        {currentStep === 2 && <TestValidation />}
        {currentStep === 3 && <Deploy />}
      </div>

      <div style={{ marginTop: '32px', textAlign: 'center' }}>
        <Space>
          {currentStep > 0 && (
            <Button onClick={handlePrev}>Previous</Button>
          )}
          {currentStep < steps.length - 1 && (
            <Button type="primary" onClick={handleNext}>
              Next
            </Button>
          )}
        </Space>
      </div>

      {/* Test Modal */}
      <Modal
        title="Test Your Agent"
        open={showTestModal}
        onCancel={() => setShowTestModal(false)}
        width={600}
        footer={[
          <Button key="cancel" onClick={() => setShowTestModal(false)}>
            Cancel
          </Button>,
          <Button 
            key="test" 
            type="primary" 
            loading={isTestingAgent}
            onClick={() => handleTest({
              // Sample test data based on template type
              ...(selectedTemplate?.templateCategory === 'IMAGE_AI' && {
                image_url: 'https://example.com/test-image.jpg',
                analysis_type: ['health', 'condition']
              }),
              ...(selectedTemplate?.templateCategory === 'VOICE_AI' && {
                audio_url: 'https://example.com/test-audio.wav',
                analysis_focus: ['wellness', 'confusion']
              }),
              ...(selectedTemplate?.templateCategory === 'SENSOR_AI' && {
                sensor_data: [{ timestamp: new Date(), value: 23.5 }],
                equipment_type: 'motor'
              })
            })}
          >
            Run Test
          </Button>
        ]}
      >
        <div>
          <Paragraph>
            This will run a test execution of your agent with sample data to verify it's working correctly.
          </Paragraph>
          
          {selectedTemplate && (
            <div>
              <Text strong>Template:</Text> {selectedTemplate.templateName}
              <br />
              <Text strong>Estimated Cost:</Text> ~${selectedTemplate.estimatedCostPerUse}
              <br />
              <Text strong>Expected Processing Time:</Text> 2-5 seconds
            </div>
          )}
        </div>
      </Modal>
    </div>
  );
};

export default AgentBuilder; 