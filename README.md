I followed the guidance in the GitHub App template (and used the template to create this default branch protector).

## Install

To run the code, make sure you have [Bundler](http://gembundler.com/) installed; then enter `bundle install` on the command line.

You will also need smee setup on your machine as well.  I used the smee node client, following the install directions in the [Smee README](https://github.com/probot/smee-client).

## Set environment variables

1. Create a copy of the `.env-example` file called `.env`.
2. Add your GitHub App's private key, app ID, and webhook secret to the `.env` file. -- please contact @lydiatripp for this information as I do not want to publically post this information.

## Run the server

1. Run `ruby template_server.rb` on the command line.
1. View the default Sinatra app at `localhost:3000`.


## Run Smee

1. get the smee url from @lydiatripp
2. run `smee -u URL --path /event_handler` on the command line.

## Create a New Repo

Once you are running the server and are running Smee, you can see the app work! 

1. Create a new repository in the TrippOrg organization, make sure you create a readme at the same time as you create the reop.
2. Refresh the new repo main page after the repo is created, you will see that there is now 1 issue, and that @lydiatripp has been notified that the master branch is protected.  
3. If you go to the settings for the new repo and click on Branches in the table on the left side of the screen, you will notice that that master branch is protected. If you click edit to edit the branch protection rules for the master branch, you will notice that it is not very protected. A further enhancement to this project should allow the runner of the server to configure preferences for the branch protection.  

## Outside Resources

1. I used (https://developer.github.com/apps/quickstart-guides/using-the-github-api-in-your-app/) to learn how to create a GitHub app. I also used the template that was available as a part of this quickstart guide (https://github.com/github-developer/using-the-github-api-in-your-app).
2. [Octokit Ruby Gem](https://github.com/octokit/octokit.rb)
3. [Smee.io](https://smee.io/) and the smee node client [Smee README](https://github.com/probot/smee-client). When you open up a smee channel, it allows a locally running server to respond to webhook events. 
4. The [GitHub App API](https://developer.github.com/v3/)
5. The internet. I did a lot of searching and experimenting to see others solutions to similar problems as I iterated while developing my app. 

