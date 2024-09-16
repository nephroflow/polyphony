# frozen_string_literal: true

require_relative 'helper'

class ThreadTest < MiniTest::Test
  def test_thread_spin
    buffer = []
    f = spin { (1..3).each { |i| snooze; buffer << i } }
    t = Thread.new do
      sleep 0.01
      s1 = spin { (11..13).each { |i| snooze; buffer << i } }
      s2 = spin { (21..23).each { |i| snooze; buffer << i } }
      sleep 0.02
      Fiber.current.await_all_children
    end
    f.join
    t.join
    t = nil

    assert_equal [1, 2, 3, 11, 12, 13, 21, 22, 23], buffer.sort
  ensure
    t&.kill
    t&.join
  end

  def test_thread_join
    buffer = []
    spin { (1..3).each { |i| snooze; buffer << i } }
    t = Thread.new { sleep 0.01; buffer << 4; :foo }

    r = t.join
    t = nil

    assert_equal :foo, r
    assert_equal [1, 2, 3, 4], buffer
  ensure
    t&.kill
    t&.join
  end

  def test_thread_join_with_timeout
    buffer = []
    f = spin { (1..3).each { |i| snooze; buffer << i } }
    t = Thread.new { sleep 1; buffer << 4 }
    t0 = Time.now
    r = t.join(0.01)
    t = nil

    assert Time.now - t0 < 0.2
    f.join
    assert_equal [1, 2, 3], buffer
    assert_nil r
  ensure
    # killing the thread will prevent stopping the sleep timer, as well as the
    # thread's event selector, leading to a memory leak.
    t&.kill
    t&.join
  end

  def test_thread_await_alias_method
    buffer = []
    spin { (1..3).each { |i| snooze; buffer << i } }
    t = Thread.new { sleep 0.1; buffer << 4; :foo }
    r = t.await
    t = nil

    assert_equal [1, 2, 3, 4], buffer
    assert_equal :foo, r
  ensure
    t&.kill
    t&.join
  end

  def test_join_race_condition_on_thread_spawning
    buffer = []
    t = Thread.new do
      :foo
    end
    r = t.join
    t = nil
    assert_equal :foo, r
  ensure
    t&.kill
    t&.join
  end

  def test_thread_uncaught_exception_propagation
    ready = Polyphony::Event.new

    t = Thread.new do
      ready.signal
      sleep 0.01
      raise 'foo'
    end
    e = nil
    begin
      ready.await
      r = t.await
    rescue Exception => e
    end
    t = nil
    assert_kind_of RuntimeError, e
    assert_equal 'foo', e.message
  ensure
    t&.kill
    t&.join
  end

  def test_thread_inspect
    lineno = __LINE__ + 1
    t = Thread.new { sleep 1 }
    str = format(
      "#<Thread:%d %s:%d",
      t.object_id,
      __FILE__,
      lineno,
    )
    assert t.inspect =~ /#{str}/
  rescue => e
    p e
    puts e.backtrace.join("\n")
  ensure
    t&.kill
    t&.join
  end

  def test_backend_class_method
    assert_equal Thread.current.backend, Thread.backend
  end

  def test_that_suspend_returns_immediately_if_no_watchers
    records = []
    Thread.backend.trace_proc = proc {|*r| records << r }
    suspend
    assert_equal [
      [:block, Fiber.current, ["#{__FILE__}:#{__LINE__ - 2}:in #{inspect_method_name_for(self.class.name, __method__.to_s)}"] + caller]
    ], records
  ensure
    Thread.backend.trace_proc = nil
  end

  def test_thread_child_fiber_termination
    buffer = []
    t = Thread.new do
      spin do
        sleep 61
      ensure
        buffer << :foo
      end
      spin do
        sleep 62
      ensure
        buffer << :bar
      end
      assert 2, Fiber.current.children.size
      sleep 1
    end
    sleep 0.05
    assert_equal 2, t.main_fiber.children.size
    t.kill
    t.join
    t = nil

    assert_equal [:foo, :bar], buffer
  ensure
    t&.kill
    t&.join
  end

  def test_idle_gc
    GC.disable

    count = GC.count
    snooze
    assert_equal count, GC.count
    sleep 0.01
    assert_equal count, GC.count

    Thread.current.idle_gc_period = 0.1
    snooze
    assert_equal count, GC.count
    sleep 0.05
    assert_equal count, GC.count

    return unless IS_LINUX

    # The idle tasks are ran at most once per fiber switch, before the backend
    # is polled. Therefore, the second sleep will not have triggered a GC, since
    # only 0.05s have passed since the gc period was set.
    sleep 0.07
    assert_equal count, GC.count
    # Upon the third sleep the GC should be triggered, at 0.12s post setting the
    # GC period.
    sleep 0.05
    assert_equal count + 1, GC.count

    Thread.current.idle_gc_period = 0
    count = GC.count
    sleep 0.001
    sleep 0.002
    sleep 0.003
    assert_equal count, GC.count
  ensure
    GC.enable
  end

  def test_on_idle
    counter = 0

    Thread.current.on_idle { counter += 1 }

    3.times { snooze }
    assert_equal 0, counter

    sleep 0.01
    assert_equal 1, counter
    sleep 0.01
    assert_equal 2, counter

    assert_equal 2, counter
    3.times { snooze }
    assert_equal 2, counter
  end

  def test_cross_thread_receive
    buf = []
    f = Fiber.current
    t = Thread.new do
      f << true
      while (msg = receive)
        buf << msg
      end
    end

    receive # wait for thread to be ready
    t << 1
    t << 2
    t << 3
    t << nil

    t.join
    assert_equal [1, 2, 3], buf
  end

  def test_value
    t = Thread.new { sleep 0.01; :foo }
    assert_equal :foo, t.value

    t = Thread.new { sleep 0.01; raise 'foo' }
    assert_raises { t.value }
    assert !t.alive?
  end
end
