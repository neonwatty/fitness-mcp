require 'fast_mcp'

module FitnessMcp
  class Server
    def self.build(mode: :production)
      server = FastMcp::Server.new(
        name: 'fitness-mcp',
        version: '2.0.0'
      )
      
      # Configure logging based on mode
      case mode
      when :debug
        server.logger = FastMcp::Logger.new(transport: :stdio)
        server.logger.level = Logger::DEBUG
      when :production, :fast
        server.logger = FastMcp::Logger.new(transport: :stdio)
        server.logger.level = Logger::ERROR
      when :silent
        server.logger = FastMcp::Logger.new(transport: :stdio)
        server.logger.level = Logger::FATAL
      end
      
      # Register tools and resources
      register_tools(server)
      register_resources(server)
      
      server
    end
    
    private
    
    def self.register_tools(server)
      tool_classes = [
        LogSetTool,
        GetLastSetTool,
        GetLastSetsTool,
        GetRecentSetsTool,
        DeleteLastSetTool,
        AssignWorkoutTool
      ]
      
      tool_classes.each do |tool_class|
        server.register_tool(tool_class)
      end
    end
    
    def self.register_resources(server)
      # Load resource classes
      require_relative '../app/resources/workout_history_resource'
      require_relative '../app/resources/user_stats_resource'
      require_relative '../app/resources/exercise_list_resource'
      
      # Register resources
      server.register_resource(WorkoutHistoryResource)
      server.register_resource(UserStatsResource)
      server.register_resource(ExerciseListResource)
    end
  end
end