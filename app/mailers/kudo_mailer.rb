class KudoMailer < ActionMailer::Base
  include Resque::Mailer # see README in this directory

  layout 'mailer'
  helper :mailer
  default from: "Archive of Our Own " + "<#{ArchiveConfig.RETURN_ADDRESS}>"

  # send a batched-up notification 
  # user_kudos is a hash of arrays converted to JSON string format
  # [commentable_type]_[commentable_id] =>
  #   names: [array of users who left kudos with the last entry being "# guests" if any]
  #   guest_count: number of guest kudos
  def batch_kudo_notification(user_id, user_kudos)
    @commentables = []
    @kudo_givers = {}
    user = User.find(user_id)
    kudos_hash = JSON.parse(user_kudos)

    I18n.with_locale(Locale.find(user.preference.preferred_locale).iso) do
      kudos_hash.each_pair do |commentable_info, kudo_givers_hash|
        # Parse the key to extract the type and id of the commentable - skip if no commentable
        commentable_type, commentable_id = commentable_info.split('_')
        commentable = commentable_type.constantize.find_by_id(commentable_id)
        next unless commentable

        # If we have a commentable, extract names and process guest kudos text - skip if no kudos givers
        names = kudo_givers_hash['names']
        guest_count = kudo_givers_hash['guest_count']
        kudo_givers = {}

        if !names.nil? && names.size > 0
          kudo_givers = names
          kudo_givers << guest_kudos(guest_count) unless guest_count == 0
        else
          kudo_givers << guest_kudos(guest_count).capitalize unless guest_count == 0
        end
        kudo_givers << "there were #{guest_count} I beleive this will be 0 as it does not go though the hash"
        next if kudo_givers.empty?

        @commentables << commentable
        @kudo_givers[commentable_info] = kudo_givers.to_sentence
      end
      mail(
        to: user.email,
        subject: "[#{ArchiveConfig.APP_SHORT_NAME}] #{t 'mailer.kudos.youhave'}"
      )
    end
    ensure
      I18n.locale = I18n.default_locale
  end

  def guest_kudos(guest_count)
    if guest_count.to_i == 1
      "1111 #{t 'mailer.kudos.guest'}"
    end
    if guest_count.to_i > 1
      "1111 #{guest_count} #{t 'mailer.kudos.guests'}"
    end
  end
end
