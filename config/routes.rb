Rails.application.routes.draw do
	devise_for :users, skip: [:registrations], controllers: {
		sessions: 'users/sessions',
		passwords: 'users/passwords'
	}

	# API endpoints
	get '/api/current_user', to: 'api#me'
	get '/api/csrf_token', to: 'api#csrf_token'

	namespace :api do
		# Public (no auth) endpoint used by the enrollment application page
		get 'public/programs/:id', to: 'programs#public_show'

		resources :families, only: [:index, :show, :create, :update, :destroy]
		resources :parents, only: [:index, :show, :create, :update, :destroy]
		resources :children, only: [:index, :show, :create, :update, :destroy]
		resources :programs, only: [:index, :show, :create, :update, :destroy]
		resources :program_classes, only: [:index, :show, :create, :update, :destroy]
		resources :program_enrollments, only: [:index, :show, :create, :update, :destroy]
		resources :payments, only: [:index, :show, :create, :destroy] do
			member do
				post :send_invoice
			end
		end
		resources :locations, only: [:index, :show, :create, :update, :destroy]
		resources :teachers, only: [:index, :show, :create, :update, :destroy]
		resources :users, only: [:index, :create, :update, :destroy]
		resources :content_items, only: [:index, :create, :update, :destroy]

		# Teacher assignments and enrollment invites
		resources :programs, only: [] do
			member do
				post :assign_teacher
				delete :unassign_teacher
				post :send_enrollment_invite
			end
		end
		resources :program_classes, only: [] do
			member do
				post :assign_teacher
				delete :unassign_teacher
			end
		end

		# Reports
		get 'reports/weekly_revenue', to: 'reports#weekly_revenue'

		# Enrollment workflow
		resources :enrollment_applications, only: [:index, :show, :create, :update] do
			collection do
				get :counts
			end
			member do
				post :mark_reviewed
				post :decline
				post :complete_meeting
				post :request_fee
				post :process_fee_payment
				post :send_enrollment_forms
				post :confirm_enrollment
				patch :update_parent_email
				patch :update_custom_fees
				post :send_email
				post :send_meeting_invite
			end
		end

		resources :events, only: [:index, :show, :create, :update] do
			member do
				post :complete
				post :cancel
				post :confirm
			end
		end

		resources :payment_plans, only: [:index, :show, :create, :update, :destroy]

		resources :enrollment_payment_plans, only: [:show, :create, :update] do
			member do
				post :record_enrollment_fee
				post :record_installment_payment
			end
		end

		# Admin integration settings (Gmail mailbox connection)
		namespace :admin do
			get 'integrations/gmail', to: 'integrations#gmail'
			delete 'integrations/gmail', to: 'integrations#disconnect_gmail'
		end
	end

	# Gmail OAuth connect/callback (full-page redirects, not JSON)
	namespace :admin do
		get 'integrations/gmail/connect', to: 'integrations#gmail_connect'
		get 'integrations/gmail/callback', to: 'integrations#gmail_callback'
	end

	# Public meeting confirmation (no auth required)
	get '/meetings/:token/confirm', to: 'meeting_confirmations#show', as: :meeting_confirmation
	post '/meetings/:token/confirm', to: 'meeting_confirmations#confirm', as: :meeting_confirmation_confirm

	# Public payment selection (no auth required)
	get '/payment/:token', to: 'payment_selections#show', as: :payment_selection
	post '/payment/:token', to: 'payment_selections#confirm', as: :payment_selection_confirm

	root "application#show"

	# Catch-all route for React Router - must be last
	get "*path", to: "application#show", constraints: ->(req) { !req.xhr? && req.format.html? }
end
