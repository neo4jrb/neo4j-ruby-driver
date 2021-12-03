
# Copyright (c) "Neo4j"
# Neo4j Sweden AB [http://neo4j.com]

# This file is part of Neo4j.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Neo4j::Driver
  module Internal
    module Async
      module Connection
        class BootstrapFactory
          class << self
            def new_bootstrap(param)
              event_loop_group = param.is_a?(Integer) ? EventLoopGroupFactory.newEventLoopGroup(param) : param

              bootstrap = io.netty.bootstrap.Bootstrap.new
              bootstrap.group(event_loop_group)
              bootstrap.channel(EventLoopGroupFactory.channel_class)
              bootstrap.option(io.netty.channel.ChannelOption.SO_KEEPALIVE, true)
              bootstrap.option(io.netty.channel.ChannelOption.SO_REUSEADDR, true)
              bootstrap
            end
          end
        end
      end
    end
  end
end
