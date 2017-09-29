= README

This app consists of Canvas Tools for Canvas Support Admins. It's a Ruby on Rails App that uses the Canvas API to pull data you can't get through the Canvas UI.

== STATUS

I have only included the ToolService file, which does the basic tasks of running the full tool report. I will be uploading the entire app when I am finished cleaning it up, but this is a good starting point.

I am still in the process of writing this README, so it's defintely a work in progress.

== Requirements

  * Ruby v. 2.2.5 +

== Services

  === Heroku Scheduler

    You should add Heroku scheduler or something similar to your app to allow for reports to run overnight, so that there is always a recent report to get data from and large reports don't need to be run during the day (and will probably time out).

    As described in Heroku Scheduler's [documentation](https://devcenter.heroku.com/articles/scheduler#installing-the-add-on), I created the file lib/tasks/scheduler.rake to contain the rake tasks to run overnight.

    I set up Heroku Scheduler as follows:

    $ rake run_tool_report_by_school
    Frequency: Daily
    Next Due: 5:00 UTC (1 am EST)

    You can check the scheduler file at lib/tasks/scheduler.rake to see how I set it up.

== Installation

  This application requires [Postgres](http://www.postgresql.org/) to be installed

    git clone git://github.com/canvasatyale/alinastools.git
    cd alinastools
    bundle install

    bundle exec rake db:create
    bundle exec rake db:schema:load

== Usage

  rails server

== Dependencies

  tbd

=== Devise

  [Devise](https://github.com/plataformatec/devise) is kind of the gold standard for authenticating user accounts in a safe way. In Alina'sTools, I connected Devise to our login system, CAS, to allow for signup/login with Yale credentials. You can customize this to allow for login using your own University's credentials, Google or some other SSO option,
  or just use local credentials (not recommended because users hate remembering multiple passwords). Because I used Yale credentials, I don't have to manage passwords, and I don't have to worry about forgotten passwords, sending out emails to reset passwords, etc.

=== Dresssed

  I used [Dresssed](https://dresssed.com/) as a template for the Admin dashboard, since I was focused on functionality and didn't have a lot of time to work on the UI.
  I really recommend it because it works really nicely and easily, and the developer is very responsive. The only problem I ran into was with Turbolinks, so I just disabled that.
  Dresssed does cost money, but it's well worth it for the time it saves. If you end up purchasing it, let them know I sent you!
  After purchasing you'll receive info like this to put in your gemfile:

    source "https://dresssed.com/gems/xxxxxxxxxxx/" do
      gem "dresssed-ives", "~> 1.0.53"
    end

  I replaced my link key with x's in the above example, and replaced it with `#{ENV["DRESSSED_KEY"]}` in the gemfile and put the key in my secrets.yml folder:
    ```
    development:
      dresssed_key:
      xxxxxxxxxxx
    production:
      dresssed_key: <%= ENV["DRESSSED_KEY_BASE"] %>
    ```
  as well as in Heroku Settings -> Config Variables.

== Customization

There is a lot to customize for your university.
Some examples:
* Canvas URLs
* Devise
* LDAP connection

== Deploying to Heroku

  A successful deployment to Heroku requires a few setup steps:

  1. Generate a new secret token:

      ```
      rake secret
      ```

  2. Set the token on Heroku:

      ```
      heroku config:set SECRET_TOKEN=the_token_you_generated
      ```

  3. [Precompile your assets](https://devcenter.heroku.com/articles/rails3x-asset-pipeline-cedar)

      ```
      RAILS_ENV=production bundle exec rake assets:precompile

      git add public/assets

      git commit -m "vendor compiled assets"
      ```

  4. Add a production database to config/database.yml


=== Known Bugs

  * Invalid Access Token: The access token you copy and paste sometimes gets corrupted. In order to fix this, paste your correct access token into User Settings and save it again.

=== More stuff (tbd)

* System dependencies

* Configuration

* Services (job queues, cache servers, search engines, etc.)

* ...
