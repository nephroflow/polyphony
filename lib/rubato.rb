# frozen_string_literal: true

require 'modulation/gem'

export_default :Rubato

Rubato = import('./rubato/core')
Exceptions = import('./rubato/core/exceptions')

module Rubato
  Cancel        = Exceptions::Cancel
  Channel       = import('./rubato/core/channel')
  Coroutine     = import('./rubato/core/coroutine')
  FiberPool     = import('./rubato/core/fiber_pool')
  FS            = import('./rubato/fs')
  MoveOn        = Exceptions::MoveOn
  Net           = import('./rubato/net')
  ResourcePool  = import('./rubato/resource_pool')
  Supervisor    = import('./rubato/core/supervisor')
  Sync          = import('./rubato/core/sync')
  Thread        = import('./rubato/core/thread')
  ThreadPool    = import('./rubato/core/thread_pool')
end
