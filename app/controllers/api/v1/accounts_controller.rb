class Api::V1::AccountsController < Api::BaseController
  include AuthHelper

  skip_before_action :authenticate_user!, :set_current_user, :handle_with_exception,
                     only: [:create, :country_based_on_ip], raise: false
  before_action :check_signup_enabled, only: [:create]
  before_action :validate_captcha, only: [:create]

  skip_before_action :verify_subscription,
                     only: [:billing_subscription, :start_billing_subscription], raise: false
  before_action :fetch_account, except: [:create, :country_based_on_ip]
  before_action :check_authorization, except: [:create, :country_based_on_ip]

  rescue_from CustomExceptions::Account::InvalidEmail,
              CustomExceptions::Account::UserExists,
              CustomExceptions::Account::UserErrors,
              with: :render_error_response

  def create
    @user, @account = AccountBuilder.new(
      account_name: account_params[:account_name],
      first_name: account_params[:first_name],
      last_name: account_params[:last_name],
      email: account_params[:email],
      firebase_jwt: account_params[:firebase_jwt],
      user_password: account_params[:password],
      user: current_user,
      country: request.location.country
    ).perform
    if @user
      send_auth_headers(@user)
      render 'api/v1/accounts/create.json', locals: { resource: @user }
    else
      render_error_response(CustomExceptions::Account::SignupFailed.new({}))
    end
  end

  def show
    @latest_chatwoot_version = ::Redis::Alfred.get(::Redis::Alfred::LATEST_CHATWOOT_VERSION)
    render 'api/v1/accounts/show.json'
  end

  def update
    @account.update!(account_params.slice(:name, :locale, :domain, :support_email, :auto_resolve_duration))
  end

  def update_active_at
    @current_account_user.active_at = Time.now.utc
    @current_account_user.save!
    head :ok
  end

  def country_based_on_ip
    render json: { country: request.location.country || 'PK' }, status: :ok
  end

  def billing_subscription
    @billing_subscription = @account.account_billing_subscriptions.last
    @available_product_prices = Enterprise::BillingProductPrice.all.includes(:billing_product).limit(4)
    render 'api/v1/accounts/ee/billing_subscription.json'
  end

  def start_billing_subscription
    url = @account.create_checkout_link(Enterprise::BillingProductPrice.find(params[:product_price]))
    render json: { url: url }
  end

  private

  def fetch_account
    @account = current_user.accounts.find(params[:id])
    @current_account_user = @account.account_users.find_by(user_id: current_user.id)
  end

  def account_params
    params.permit(:account_name, :first_name, :last_name, :email, :name, :password, :locale, :domain, :support_email, :auto_resolve_duration,
                  :firebase_jwt)
  end

  def check_signup_enabled
    raise ActionController::RoutingError, 'Not Found' if GlobalConfigService.load('ENABLE_ACCOUNT_SIGNUP', 'false') == 'false'
  end

  def validate_captcha
    # TODO: Uncomment this line
    # raise ActionController::InvalidAuthenticityToken, 'Invalid Captcha' unless ChatwootCaptcha.new(params[:h_captcha_client_response]).valid?
  end

  def pundit_user
    {
      user: current_user,
      account: @account,
      account_user: @current_account_user
    }
  end
end
