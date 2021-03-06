module Camlistore
  Configuration.namespace :camlistore
  Configuration.keys :host
  Configuration.env ENV

  class Client
    attr_reader :config, :blobroot, :searchroot
    include API

    def initialize options = {}
      @config = Configuration.new(options, host: 'http://localhost:3179')
      raise ArgumentError, "You must supply blobstore host." unless config.host.present?
      remote_configuration = api_call '/', {}, {accept: 'text/x-camli-configuration'}
      @blobroot = remote_configuration['blobRoot']
      @searchroot = remote_configuration['searchRoot']
    end

    api_method :enumerate_blobs, '/bs/camli/enumerate-blobs'

    def each_blob &block
      data = enumerate_blobs
      blobs = data.blobs

      while blobs.any?
        blobs.each &block

        blobs = if data.continueAfter.present?
          data = enumerate_blobs(after: data.continueAfter)
          data.blobs
        else
          []
        end
      end
    end

    def blobref content
      'sha1-' + Digest::SHA1.hexdigest(content)
    end

    def get sha
      api_call(@blobroot + 'camli/' + sha)
    end

    def describe sha
      api_call(@searchroot + 'camli/search/describe', {'blobref' => sha})
    end

    def search query
      query = query.to_json if query.is_a?(Hash)
      api_post(@searchroot + 'camli/search/query', query)
    end

    def put content
      sha = blobref(content)
      boundary = 'randomboundaryXYZ'
      content_type = "multipart/form-data; boundary=#{boundary}"

post_body = "--#{boundary}
Content-Disposition: form-data; name='#{sha}'; filename='#{sha}'
Content-Type: application/octet-stream

#{content}
--#{boundary}--"

      api_post(@blobroot + 'camli/upload', post_body, {:content_type => content_type})
    end
  end

end
