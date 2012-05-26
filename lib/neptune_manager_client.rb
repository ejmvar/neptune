#!/usr/bin/ruby -w
# Programmer: Chris Bunch (cgb@cs.ucsb.edu)

require 'openssl'
require 'soap/rpc/driver'
require 'timeout'

# Sometimes SOAP calls take a long time if large amounts of data are being
# sent over the network: for this first version we don't want these calls to
# endlessly timeout and retry, so as a hack, just don't let them timeout.
# The next version should replace this and properly timeout and not use
# long calls unless necessary.
NO_TIMEOUT = 100000


# A client that uses SOAP messages to communicate with the underlying cloud
# platform (here, AppScale). This client is similar to that used in the AppScale
# Tools, but with non-Neptune SOAP calls removed.
class NeptuneManagerClient

  
  # The port that the Neptune Manager runs on, by default.
  SERVER_PORT = 17445


  # The SOAP client that we use to communicate with the NeptuneManager.
  attr_accessor :conn
  

  # The IP address of the NeptuneManager that we will be connecting to.
  attr_accessor :ip
  

  # The secret string that is used to authenticate this client with
  # NeptuneManagers. It is initially generated by appscale-run-instances and can
  # be found on the machine that ran that tool, or on any AppScale machine.
  attr_accessor :secret
  

  # A constructor that requires both the IP address of the machine to communicate
  # with as well as the secret (string) needed to perform communication.
  # NeptuneManagers will reject SOAP calls if this secret (basically a password)
  # is not present - it can be found in the user's .appscale directory, and a
  # helper method is usually present to fetch this for us.
  def initialize(ip, secret)
    @ip = ip
    @secret = secret
    
    @conn = SOAP::RPC::Driver.new("https://#{@ip}:#{SERVER_PORT}")
    @conn.add_method("start_job", "jobs", "secret")
    @conn.add_method("put_input", "job_data", "secret")
    @conn.add_method("get_output", "job_data", "secret")
    @conn.add_method("get_acl", "job_data", "secret")
    @conn.add_method("set_acl", "job_data", "secret")
    @conn.add_method("compile_code", "job_data", "secret")
    @conn.add_method("get_supported_babel_engines", "job_data", "secret")
    @conn.add_method("does_file_exist", "file", "job_data", "secret")
    @conn.add_method("get_profiling_info", "key", "secret")
  end


  # A helper method to make SOAP calls for us. This method is mainly here to
  # reduce code duplication: all SOAP calls expect a certain timeout and can
  # tolerate certain exceptions, so we consolidate this code into this method.
  # Here, the caller specifies the timeout for the SOAP call (or NO_TIMEOUT
  # if an infinite timeout is required) as well as whether the call should
  # be retried in the face of exceptions. Exceptions can occur if the machine
  # is not yet running or is too busy to handle the request, so these exceptions
  # are automatically retried regardless of the retry value. Typically
  # callers set this to false to catch 'Connection Refused' exceptions or
  # the like. Finally, the caller must provide a block of
  # code that indicates the SOAP call to make: this is really all that differs
  # between the calling methods. The result of the block is returned to the
  # caller. 
  def make_call(time, retry_on_except)
    begin
      Timeout::timeout(time) {
        yield if block_given?
      }
    rescue Errno::ECONNREFUSED
      if retry_on_except
        retry
      else
        raise NeptuneManagerException.new("Connection was refused. Is the NeptuneManager running?")
      end
    rescue OpenSSL::SSL::SSLError, NotImplementedError, Timeout::Error
      retry
    rescue Exception => except
      if retry_on_except
        retry
      else
        raise NeptuneManagerException.new("We saw an unexpected error of the type #{except.class} with the following message:\n#{except}.")
      end
    end
  end


  # Initiates the start of a Neptune job, whether it be a HPC job (MPI, X10,
  # or MapReduce), or a scaling job (e.g., for AppScale itself). This method
  # should not be used for retrieving the output of a job or getting / setting
  # output ACLs, but just for starting new HPC / scaling jobs. This method
  # takes a hash containing the parameters of the job to run, and can raise NeptuneManagerException.new if
  # the NeptuneManager it calls returns an error (e.g., if a bad secret is used
  # or the machine isn't running). Otherwise, the return value of this method
  # is the result returned from the NeptuneManager.
  def start_neptune_job(job_data)
    result = ""
    make_call(NO_TIMEOUT, false) { 
      result = conn.start_job(job_data, @secret)
    }  
    raise NeptuneManagerException.new(result) if result =~ /Error:/
    return result
  end


  # Stores a file stored on the user's local file system in the underlying
  # database. The user can specify to use either the underlying database
  # that AppScale is using, or alternative storage mechanisms (as of writing,
  # Google Storage, Amazon S3, and Eucalyptus Walrus are supported) via the
  # storage parameter.
  def put_input(job_data)
    result = ""
    make_call(NO_TIMEOUT, false) {
      result = conn.put_input(job_data, @secret)
    }  
    raise NeptuneManagerException.new(result) if result =~ /Error:/
    return result
  end


  # Retrieves the output of a Neptune job, stored in an underlying
  # database. Within AppScale, a special application runs, referred to as the
  # Repository, which provides a key-value interface to Neptune job data.
  # Data is stored as though it were on a file system, therefore output
  # be of the usual form /folder/filename . Currently the contents of the
  # file is returned as a string to the caller, but as this may be inefficient
  # for non-trivial output jobs, the next version of Neptune will add an
  # additional call to directly copy the output to a file on the local
  # filesystem. See start_neptune_job for conditions by which this method
  # can raise NeptuneManagerException.new as well as the input format used for job_data.
  def get_output(job_data)
    result = ""
    make_call(NO_TIMEOUT, false) { 
      result = conn.get_output(job_data, @secret)
    }  
    raise NeptuneManagerException.new(result) if result =~ /Error:/
    return result
  end


  # Returns the ACL associated with the named piece of data stored
  # in the underlying cloud platform. Right now, data can only be
  # public or private, but future versions will add individual user
  # support. Input, output, and exceptions mirror that of
  # start_neptune_job.
  def get_acl(job_data)
    result = ""
    make_call(NO_TIMEOUT, false) { 
      result = conn.get_acl(job_data, @secret)
    }  
    raise NeptuneManagerException.new(result) if result =~ /Error:/
    return result
  end


  # Sets the ACL of a specified pieces of data stored in the underlying
  # cloud platform. As is the case with get_acl, ACLs can be either
  # public or private right now, but this will be expanded upon in
  # the future. As with the other SOAP calls, input, output, and exceptions
  # mirror that of start_neptune_job.
  def set_acl(job_data)
    result = ""
    make_call(NO_TIMEOUT, false) { 
      result = conn.set_acl(job_data, @secret)
    }  
    raise NeptuneManagerException.new(result) if result =~ /Error:/
    return result
  end


  # Instructs the NeptuneManager to fetch the code specified and compile it.
  # The result should then be placed in a location specified in the job data.
  def compile_code(job_data)
    result = ""
    make_call(NO_TIMEOUT, false) { 
      result = conn.compile_code(job_data, @secret)
    }  
    raise NeptuneManagerException.new(result) if result =~ /Error:/
    return result
  end


  # Asks the NeptuneManager for a list of all the Babel engines (each of which
  # is a queue to store jobs and something that executes tasks) that are
  # supported for the given credentials.
  def get_supported_babel_engines(job_data)
    result = []
    make_call(NO_TIMEOUT, false) {
      result = conn.get_supported_babel_engines(job_data, @secret)
    }
    return result
  end


  # Asks the NeptuneManager to see if the given file exists in the remote
  # datastore. If extra credentials are needed for this operation, they are
  # searched for within the job data.
  def does_file_exist?(file, job_data)
    result = false
    make_call(NO_TIMEOUT, false) {
      result = conn.does_file_exist(file, job_data, @secret)
    }
    return result
  end


  def get_profiling_info(key)
    result = {'performance' => [], 'cost' => []}
    make_call(NO_TIMEOUT, false) {
      result = conn.get_profiling_info(key, @secret)
    }
    return result
  end


end
