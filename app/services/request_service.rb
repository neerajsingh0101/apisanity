class RequestService
  include ActiveModel::Validations
  include SanitizeUrl

  attr_reader :url, :username, :password, :method, :response, :request_params, :request_headers, :request_body, :assertions, :user_id
  attr_accessor :api_response

  validates :url, :method, presence: true

  def initialize(url, method, options={})
    @url = url
    @method = method || :get
    @username = options[:username]
    @password = options[:password]
    @request_params = options[:request_params]
    @request_body = options[:request_body]
    @request_headers = options[:request_headers]
    @assertions = options[:assertions]
    @user_id = options[:user_id]
  end

  def process
    if valid?
      begin
        connection = Excon.new(sanitize_url(url))
        @response = connection.request(options)
        self.api_response = save_api_response
      rescue Excon::Error::Socket => e
        errors.add(:url, 'Invalid URL or Domain')
      end
    end
  end

  private

  def save_api_response
    ApiResponse.create!({ url: url,
                        method: method.upcase,
                        response: response_body,
                        response_headers: response.headers,
                        status_code: response.status,
                        request_headers: request_headers,
                        request_params: request_params.is_a?(String) ? JSON.parse(request_params) : sanitized_request_params,
                        username: username,
                        password: password,
                        user_id: user_id,
                        request_body: request_body }.merge(assertion_attributes)
                       )
  end

  def sanitized_request_params
    {}.tap do |return_value|
      request_params.each do |key, value|
        return_value[key] = value.is_a?(ActionDispatch::Http::UploadedFile) ? '' : value
      end
    end
  end

  def authorization_options
    if username && password
      {user: username, password: password}
    else
      {}
    end
  end

  def response_body
    {
      body: response.body.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    }
  end

  def options
    {method: method, :verify_ssl => false, headers: request_headers}.merge(authorization_options).merge(body: URI.encode_www_form(request_params))
  end

  def assertion_attributes
    if assertions.present?
      { assertions_attributes: assertions }
    else
      {}
    end
  end
end
