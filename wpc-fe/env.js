// This file will be run when the index.html is loaded and read in the environment variables if present
// otherwise it will setup some defaults
// Source for this work : https://www.jvandemo.com/how-to-use-environment-variables-to-configure-your-angular-application-without-a-rebuild/

(function (window) {
    window.__env = window.__env || {};
  
    // API url
    window.__env.apiUrl = 'dev.your-api.com';

    window.__env.envFileLoaded = true;
  
  }(this));