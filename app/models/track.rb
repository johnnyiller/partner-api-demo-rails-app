# Example track class illustrating how one might use the music xray partner api
# This is not exhaustive.  There are many more advanced features that music xray
# can help you take advantage of on a case by case basis.  For more details please
# send inquiries to jeff@musicxray.com
class Track < ActiveRecord::Base
  
  
  has_attached_file :mp3_file,
                    :storage => :s3,
                    :s3_credentials => {:access_key_id => AppConfig.amazon["access_key"], :secret_access_key => AppConfig.amazon["secret_key"], :bucket => AppConfig.amazon["bucket"]},
                    :path => "tracks/:id/file.mp3",
                    :s3_headers => {"Content-Disposition" => "attachment", "Content-Type" => "application/octet-stream"}

  attr_accessible :mp3_file
  
  before_destroy :cleanup

  # Some code to make sure the api is using the proper credentials
  # At the moment you must make sure you run this code before making 
  # a call to the Api.  The access_key and secret key should be obvious
  # if you have already signed up for our api.  If you have not been marked
  # in our database as a partner you will get authentication errors
  # so please send an email to jeff@musicxray.com before using the api.
  def self.setup_xray_api
    MusicXrayApi::Base.key = AppConfig.partner_api["access_key"]
    MusicXrayApi::Base.secret = AppConfig.partner_api["secret_key"]
    MusicXrayApi::Base.api_endpoint = "https://api.musicxray.com"
    MusicXrayApi::Track.set_headers
    MusicXrayApi::Track.set_headers
    MusicXrayApi::TrackSet.set_headers
    MusicXrayApi::TrackSetMember.set_headers
    MusicXrayApi::TrackMatchRequest.set_headers
  end
  
  # Get's the current track on our partner api and returns it as a useable object
  def partner_api_track
    begin 
      Track.setup_xray_api
      params = {:application_name=>AppConfig.partner_api["application_name"],:application_id=>self.id}
      @t ||= MusicXrayApi::Track.find(:all,:params=>params).first
      if @t
        return @t
      else
        return nil 
      end
    rescue
      return nil
    end
  end
  
  # adds the local track to the partner api.  Notice how you do not actually upload a song to us.
  # You simply tell us the location of the mp3 and we will fetch it.  Note, the mp3 must be available
  # publically before making this request or we will fail to find the file.  Notice there is a post_back_url
  # parameter.  In an effort to avoid constant pinging of our servers we notify you when events occur as it relates
  # to this particular track.  At the moment we simply tell you when a tracks features have been extracted.
  # Upon extraction of features, the track is ready to be matched to other tracks or to drop boxes on our site.
  def add_partner_api
    Track.setup_xray_api
    attrs = {:mp3_url => self.mp3_file.url,
               :application_name => AppConfig.partner_api["application_name"],
               :application_id => self.id,
               :extracted => false,
               :post_back_url => "#{AppConfig.root_url}/xrays/#{self.id}/feature_postback",
               :uri => "partner-api-demo-#{Rails.env}/tracks/#{self.id}"}
    begin
        @t = MusicXrayApi::Track.create(attrs)
      return @t
    rescue
      return nil
    end
  end
  
  # self explanatory
  def cleanup
    self.partner_api_track.destroy rescue "Could not delete track"
  end

  # Once your song has had it's features extracted you can request to match it with track sets.
  # We have a system track set called drop_boxes.  Calling the following code will initial a track match
  # request for the track id specified.  Notice that this also takes a post_back_url.  This allows us to notify
  # your server when the matches are ready.  When they are you can send your users and email, cache the results, or do 
  # some other application specific action.
  def generate_matches
    
    if self.partner_api_track
      params = {:track_id=>self.partner_api_track.id, 
                :track_set_id=>"drop_boxes",
                :result_delivery_method=>'postback',
                :post_back_url=>"#{AppConfig.root_url}/xrays/#{self.id}/match_postback"}
      begin          
        MusicXrayApi::TrackMatchRequest.create(params) 
      rescue
        nil
      end
    else
      nil
    end
  end

end
