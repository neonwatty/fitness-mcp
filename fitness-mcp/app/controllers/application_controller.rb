class ApplicationController < ActionController::Base
  def info
    render json: {
      name: 'Fitness MCP Server',
      version: '1.0.0',
      description: 'Fitness tracking and planning tool with MCP integration',
      endpoints: {
        api: '/api/v1',
        documentation: 'https://github.com/your-repo/fitness-mcp'
      },
      features: [
        'User registration and authentication',
        'API key management',
        'Workout set logging',
        'Exercise history tracking',
        'Workout assignment planning',
        'Model Context Protocol (MCP) integration'
      ]
    }
  end
end
