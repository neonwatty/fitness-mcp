class ApplicationController < ActionController::Base
  def info
    respond_to do |format|
      format.json do
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
      
      format.html do
        @api_info = {
          name: 'Fitness MCP Server',
          version: '1.0.0',
          description: 'Fitness tracking and planning tool with MCP integration',
          base_url: request.base_url,
          api_base: '/api/v1'
        }
        render 'application/info'
      end
    end
  end
end
