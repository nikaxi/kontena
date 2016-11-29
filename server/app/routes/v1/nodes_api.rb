module V1
  class NodesApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers

    route do |r|

      validate_access_token
      require_current_user

      # @param [String] grid_name
      # @param [String] node_id
      # @return [HostNode]
      def load_grid_node(grid_name, node_id)
        grid = Grid.find_by(name: grid_name)
        halt_request(404, {error: 'Not found'}) if !grid

        if node_id.include?(':')
          node = grid.host_nodes.find_by(node_id: node_id)
        else
          node = grid.host_nodes.find_by(name: node_id)
        end
        halt_request(404, {error: 'Not found'}) if !node

        unless current_user.grid_ids.include?(grid.id)
          halt_request(403, {error: 'Access denied'})
        end

        node
      end

      r.on ':grid_name/:node_id' do |grid_name, node_id|
        @node = load_grid_node(grid_name, node_id)

        r.get do
          r.is do
            render('host_nodes/show')
          end
        end

        r.put do
          r.is do
            data = parse_json_body
            params = { host_node: @node }
            params[:labels] = data['labels'] if data['labels']
            outcome = HostNodes::Update.run(params)
            if outcome.success?
              @node = outcome.result
              render('host_nodes/show')
            else
              halt_request(422, {error: outcome.errors.message})
            end
          end
        end

        r.delete do
          r.is do
            audit_event(r, @grid, @node, 'remove node')
            outcome = HostNodes::Remove.run(host_node: @node)
            if outcome.success?
              {}
            else
              halt_request(422, {error: outcome.errors.message})
            end
          end
        end
      end
    end
  end
end
