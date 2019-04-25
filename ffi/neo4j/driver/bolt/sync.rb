# frozen_string_literal: true

module Bolt
  module Sync
    extend Bolt::Library

    attach_function :mutex_create, :BoltSync_mutex_create, %i[pointer], :int
    attach_function :mutex_destroy, :BoltSync_mutex_destroy, %i[pointer], :int
    attach_function :mutex_lock, :BoltSync_mutex_lock, %i[pointer], :int
    attach_function :mutex_unlock, :BoltSync_mutex_unlock, %i[pointer], :int
    attach_function :mutex_trylock, :BoltSync_mutex_trylock, %i[pointer], :int
    attach_function :rwlock_create, :BoltSync_rwlock_create, %i[pointer], :int
    attach_function :rwlock_destroy, :BoltSync_rwlock_destroy, %i[pointer], :int
    attach_function :rwlock_rdlock, :BoltSync_rwlock_rdlock, %i[pointer], :int
    attach_function :rwlock_wrlock, :BoltSync_rwlock_wrlock, %i[pointer], :int
    attach_function :rwlock_tryrdlock, :BoltSync_rwlock_tryrdlock, %i[pointer], :int
    attach_function :rwlock_trywrlock, :BoltSync_rwlock_trywrlock, %i[pointer], :int
    attach_function :rwlock_timedrdlock, :BoltSync_rwlock_timedrdlock, %i[pointer int], :int
    attach_function :rwlock_timedwrlock, :BoltSync_rwlock_timedwrlock, %i[pointer int], :int
    attach_function :rwlock_rdunlock, :BoltSync_rwlock_rdunlock, %i[pointer], :int
    attach_function :rwlock_wrunlock, :BoltSync_rwlock_wrunlock, %i[pointer], :int
    attach_function :cond_create, :BoltSync_cond_create, %i[pointer], :int
    attach_function :cond_destroy, :BoltSync_cond_destroy, %i[pointer], :int
    attach_function :cond_signal, :BoltSync_cond_signal, %i[pointer], :int
    attach_function :cond_broadcast, :BoltSync_cond_broadcast, %i[pointer], :int
    attach_function :cond_wait, :BoltSync_cond_wait, %i[pointer pointer], :int
    attach_function :cond_timedwait, :BoltSync_cond_timedwait, %i[pointer pointer int], :int
  end
end
