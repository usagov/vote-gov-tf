locals {

  ## The name of the project. Used to name most applications and services.
  ## Default naming convention: ${local.project}-application-name-${terraform.workspace}
  project = "vote"

  ## The full name of the project. If their isn't a longer name, this can be set to
  ## local.project.
  project_full = "${local.project}-gov"

  ## The name of the bootstrap/init workspace. This is used for various things, such as
  ## creating global pipeline variables that aren't project specific.
  bootstrap_workspace = "bootstrap"

  ## The names of the project's production workspaces. This is used to adjust
  ## settings dynamically throughout this configuration file.
  production_workspaces = ["prod", "stage"]

  ## "Common" applications and services that are deployed to every space.
  globals = {
    apps = {
      ## Nginx Web Application Firewall (WAF).
      waf = {

        ## Should the application have access to the internet?
        allow_egress = true

        ## Buildpacks to use with this application.
        ## List buildpacks avalible with: cf buildpacks
        buildpacks = [
          "https://github.com/cloudfoundry/apt-buildpack",
          "nginx_buildpack"
        ]

        ## Command to run when container starts.
        command = "./start"

        ## Ephemeral disk storage.
        disk_quota = 1024

        ## Should SSH be enabled?
        enable_ssh = true

        ## Environmental variables. Avoid sensitive variables.
        environment = {

          ## IP addresses allowed to connected to the CMS.
          ALLOWED_IPS = base64encode(
            jsonencode([
              ## GSA VPN pool.
              "159.142.0.0/16 allow;",
              "173.66.119.38/32 allow;",
              "10.190.128.0/22 allow;",
              local.cloudfront_ips_allowed
            ])
          )

          ## The OWASP CRS rules for modsecurity.
          CRS_RULES = "coreruleset-3.3.4.tar.gz"

          ## The current environment the application is running in.
          ENV = terraform.workspace

          ## Linux "Load Library Path", where system libraries are located. (i.e. libzip, gd, etc)
          LD_LIBRARY_PATH = "/home/vcap/deps/0/lib/"

          ## Ubuntu patch for newer version of mod security.
          MODSECURITY_UPDATE = "libmodsecurity3_3.0.9-1_amd64.deb"

          ## Domains that shouldn't be passed to the egress proxy server (i.e. apps.internal).
          no_proxy = var.no_proxy
        }

        ## Timeout for health checks, in seconds.
        health_check_timeout = 180

        ## Type of health check.
        ## Options: port, process, http
        health_check_type = "port"

        ## Number of instances of application to deploy.
        instances = 1

        ## Labels to add to the application.
        labels = {
          environment = terraform.workspace
        }

        ## Maximum amount of memory the application can use.
        memory = 64

        ## Addional network policies to add to the application.
        ## Format: name of the application and the port it is listening on.
        network_policies = {
          drupal = 8080
        }

        ## Port the application uses.
        port = 8080

        ## Can the application be accessed outside of cloud.gov?
        public_route = true

        ## The source file should be a directory or a zip file.
        source = "./applications/nginx-waf"

        ## Templates take templated files and fill them in with sensitive data.
        ## The proxy-to-static.conf has the S3 bucket written to it during
        ## the 'terraform apply' command, before it the files are zipped up and 
        ## uploaded to cloud.gov.
        templates = [
          {
            source      = "${path.cwd}/applications/nginx-waf/nginx/snippets/proxy-to-storage.conf.tmpl"
            destination = "${path.cwd}/applications/nginx-waf/nginx/snippets/proxy-to-storage.conf"
          },
          {
            source      = "${path.cwd}/applications/nginx-waf/nginx/snippets/proxy-to-static.conf.tmpl"
            destination = "${path.cwd}/applications/nginx-waf/nginx/snippets/proxy-to-static.conf"
          },
          {
            source      = "${path.cwd}/applications/nginx-waf/nginx/snippets/proxy-to-app.conf.tmpl"
            destination = "${path.cwd}/applications/nginx-waf/nginx/snippets/proxy-to-app.conf"
          }
        ]
      }
    }

    ## Services to deploy in this environment.
    services = {

      ## S3 storage for backups.
      backup = {
        ## Applications to bind to this service.
        applications = ["drupal"]

        ## Should a service key be generated for other applications to use?
        service_key = true

        ## The size of the instance to deploy.
        service_plan = "basic"

        ## The type of service to be deployed.
        service_type = "s3"

        ## Tags to add to the service.
        tags = [
          terraform.workspace
        ]
      }

      ## MySQL RDS database.
      mysql = {

        ## Applications to bind to this service.
        applications = ["drupal"]

        ## The size of the instance to deploy.
        service_plan = contains(local.production_workspaces, terraform.workspace) ? "medium-mysql" : "micro-mysql"

        ## The type of service to be deployed.
        service_type = "aws-rds"

        ## Tags to add to the service.
        tags = [
          terraform.workspace
        ]
      }

      ## Credentials and other sensitive variables.
      secrets = {
        ## Applications to bind to this service.
        applications = ["drupal", "waf"]

        ## Credentials that should be added to the json blob.
        credentials = [
          "ca_certificate",
          "ca_key",
          "cron_key",
          "hash_salt",
          "HASH_SALT",
          "newrelic_key",
          "proxy_password",
          "proxy_username",
          "proxy_uri",
          "static_bucket",
          "static_fips_endpoint",
          "static_access_key_id",
          "static_secret_access_key",
          "storage_bucket",
          "storage_fips_endpoint",
          "storage_access_key_id",
          "storage_secret_access_key"
        ]

        ## The type of service to be deployed.
        service_type = "user-provided"

        ## Tags to add to the service.
        tags = [
          terraform.workspace
        ]
      }

      ## S3 storage for public files for Drupal.
      ## Typically "sites/default/files/"
      storage = {

        ## Applications to bind to this service.
        applications = ["drupal", "waf"]

        ## Should a service key be generated for other applications to use?
        service_key = true

        ## The size of the instance to deploy.
        service_plan = "basic-public-sandbox"

        ## The type of service to be deployed.
        service_type = "s3"

        ## Tags to add to the service.
        tags = [
          terraform.workspace
        ]
      }

      ## S3 storage for the statically generated site.
      static = {

        ## Applications to bind to this service.
        applications = ["waf"]

        ## Should a service key be generated for other applications to use?
        service_key = true

        ## The size of the instance to deploy.
        service_plan = "basic-public-sandbox"

        ## The type of service to be deployed.
        service_type = "s3"

        ## Tags to add to the service.
        tags = [
          terraform.workspace
        ]
      }
    }

    ## Variables to store in CircleCI as pipeline variables.
    circleci_variables = [
      "cf_space",
      "cron_key",
      "cms_uri",
      "ssg_uri",
      "drupal_instances",
      "drupal_memory",
      "drupal_port",
      "hash_salt",
      "sso_x509_cert",
      "waf_name",
      "waf_external_endpoint"
    ]
  }

  ## Settings for the egress proxy.
  egress = {

    ## The name of the proxy.
    name = "caddy"

    ## The naming convention/pattern for systems in the proxy space. The space could be named something 
    ## besides dmz, such as public, so that can be specified here. The '%s' is replaced with the name of
    ## the application or service.
    name_pattern = "${local.project}-%s-dmz"

    ## The mTLS port the proxy application uses.
    ## Cloudfoundry will automatically redirect connections on this port to local port 8080.
    port = var.mtls_port

    ## The name of the space the proxy is deployed in.
    space = "${local.project}-dmz"

    ## The terraform workspace the proxy is deployed with.
    workspace = "dmz"
  }

  ## The mTLS port the proxy application uses.
  ## Cloudfoundry will automatically redirect connections on this port to local port 8080.
  mtls_port = var.mtls_port

  ## Any applications that are external to this Terraform infrastucture.
  ## These are saved to CircleCI variables.
  ## In this case, the Drupal application is deployed via a manifest.yml in the Drupal
  ## Github repostitory.
  external_applications = {
    dev = {
      drupal = {

        ## How many instances of the application to run.
        instances = 1

        ## Port is the application listening on.
        port = var.mtls_port

        ## How much memory should it be using?
        memory = 512
      }
    }
    prod = {
      drupal = {

        ## How many instances of the application to run.
        instances = 1

        ## Port is the application listening on.
        port = var.mtls_port

        ## How much memory should it be using?
        memory = 512

        enable_ssh = false
      }
    }
    stage = {
      drupal = {

        ## How many instances of the application to run.
        instances = 1

        ## Port is the application listening on.
        port = var.mtls_port

        ## How much memory should it be using?
        memory = 512
      }
    }
    test = {
      drupal = {

        ## How many instances of the application to run.
        instances = 1

        ## Port is the application listening on.
        port = var.mtls_port

        ## How much memory should it be using?
        memory = 512

      }
    }
  }

  ## The various environment settings to be deployed.
  envs = {

    ## Every environment gets settings in 'all'.
    all = {

      ## The API URL for cloud.gov.
      api_url = "https://api.fr.cloud.gov"

      ## Copy the bootstrap workspace name from above to be passed to modules.
      bootstrap_workspace = local.bootstrap_workspace

      //  1825 days or 5 years
      certificate_authority_validity = 43800

      // Allow renewal one month before experation.
      certificate_authority_renewal = 43080

      ## These values are defaults values when options aren't configured in the application block.
      defaults = {

        ## The default size of the containers ephemeral disk.
        disk_quota = 2048

        ## Is SSH enabled on the container by default?
        enable_ssh = true

        ## The default health check timeout.
        health_check_timeout = 60

        ## Default method of performing a health check.
        ## Valid options: "port", "process", or "http"
        ## https://docs.cloudfoundry.org/devguide/deploy-apps/healthchecks.html
        health_check_type = "port"

        ## Default number of application instances to deploy.
        instances = 1

        ## Default amount of memory to use memory to use for an application.
        memory = 64

        port = 8080

        ## The default cloudfoundry stack to deploy.
        ## https://docs.cloudfoundry.org/devguide/deploy-apps/stacks.html
        stack = "cflinuxfs4"

        ## Is the application stopped by default?
        stopped = false

        ## Default CloudFoundry deployment strategy.
        ## Valid optons: "none", "standard", or "blue-green".
        ## https://docs.cloudfoundry.org/devguide/deploy-apps/rolling-deploy.html
        strategy = "none"

        ## Default wait time for an application to start.
        timeout = 300
      }

      ## Configuration settings for the egress proxy application.
      egress = local.egress

      ## External application based on the Terraform workspace being used.
      external_applications = try(local.external_applications[terraform.workspace], {})

      ## The domain name for applications accessable external of cloud.gov.
      external_domain = "app.cloud.gov"

      ## The domain name for applications accessable inside of cloud.gov.
      internal_domain = "apps.internal"

      ## The naming convention/pattern for deployed systems and subsystems.
      ## %s is replaced with the name of the system.
      name_pattern = "${local.project}-%s-${terraform.workspace}"

      ## The name of the cloud.gov organization.
      organization = "gsa-tts-usagov"

      ## Passwords that are generated for workspaces. By default, it's an empty map.
      ## If one is defined below in a workspace's settings, it will supersed this one.
      passwords = {}

      ## CircleCI global configuration.
      circleci = {
        ## The name of the organization in CircleCI
        organization = "usagov"
        ## The name of the project in CircleCI. Typically the repo name.
        project = "${local.project_full}-drupal"
        ## The name of the version control system. The provider supports:
        ## - github
        ## - bitbucket
        vcs_type = "github"

        ## Scheduled pipeline definitions.
        schedules = {


          dev-test-upkeep = {
            name             = "${local.project}-upkeep-for-${terraform.workspace}"
            description      = "Run upkeep for ${terraform.workspace} environment."
            ignore_workspace = ["bootstrap", "dmz", "stage", "prod"]
            organization     = "usagov"
            project          = "${local.project_full}-drupal"
            per_hour         = 1
            hours_of_day     = ["*"]
            days_of_week     = ["*"]

            parameters = {
              branch = terraform.workspace
              upkeep = true
            }
          }

          stage-prod-upkeep = {
            name             = "${local.project}-upkeep-for-${terraform.workspace}"
            description      = "Run upkeep for ${terraform.workspace} environment."
            ignore_workspace = ["bootstrap", "dmz", "dev", "test"]
            organization     = "usagov"
            project          = "${local.project_full}-drupal"
            per_hour         = 2
            hours_of_day     = ["*"]
            days_of_week     = ["*"]

            parameters = {
              branch = terraform.workspace
              upkeep = true
            }
          }



          ## Runs the pipeline that backups the database, user uploaded content, and terraform state files once an hour.
          prod-scheduled-backup = {
            name             = "${local.project}-scheduled-backup-${terraform.workspace}"
            description      = "A scheduled backup job for ${terraform.workspace} environment."
            ignore_workspace = ["bootstrap", "dmz", "test", "dev", "stage"]
            organization     = "usagov"
            project          = "${local.project_full}-drupal"
            per_hour         = 1
            hours_of_day     = ["1", "16"]
            days_of_week     = ["*"]
            parameters = {
              branch           = terraform.workspace
              scheduled_backup = true
            }
          }

          preprod-scheduled-backup = {
            name             = "${local.project}-scheduled-backup-${terraform.workspace}"
            description      = "A scheduled backup job for ${terraform.workspace} environment."
            ignore_workspace = ["bootstrap", "dmz", "prod"]
            organization     = "usagov"
            project          = "${local.project_full}-drupal"
            per_hour         = 1
            hours_of_day     = ["16"]
            days_of_week     = ["*"]
            parameters = {
              branch           = terraform.workspace
              scheduled_backup = true
            }
          }
        }
      }

      ## A copy of the project name, so it gets added to this setting object.
      project = local.project

      ## The name of the current Cloud.gov space.
      space = "${local.project}-${terraform.workspace}"
    }

    ##
    ##
    ## The bootstrap workspace.
    ## Used to initialize gobal/project wide settings.
    ##
    ##

    bootstrap = {

      ## Username and password that gets generated for the egress proxy to allow egress.
      passwords = {
        proxy_username = {
          length  = 16
          special = false
        }
        proxy_password = {
          length  = 48
          special = false
        }
      }

      ## Sensitive variables to store in the pipeline.
      circleci_variables = {
        ## The variable set for egress proxy sensitive variables.
        bootstrap = {
          variables = [
            #"backend_aws_bucket_name",
            #"backend_aws_bucket_region",
            #"backup_aws_bucket_name",
            #"backup_aws_bucket_region",
            "cloudgov_password",
            "cloudgov_username",
            "circleci_token",
            "cf_org",
            "drupal_port",
            "newrelic_key",
            "no_proxy",
            "project",
            "proxy_password",
            "proxy_username"
          ]
        }
      }
    }

    ##
    ##
    ## The DMZ workspace.
    ##
    ##

    dmz = {
      ## Applications to deploy to this workspace.
      apps = {

        ## The Caddy egress proxy.
        caddy = {
          buildpacks = [
            #"https://github.com/cloudfoundry/apt-buildpack",
            "binary_buildpack"
          ]
          command    = "./start"
          disk_quota = 256
          enable_ssh = true
          environment = {
            ENV             = terraform.workspace
            LD_LIBRARY_PATH = "/home/vcap/deps/0/lib/"

            ## List of domains that applications are allowed to connect to.
            PROXY_ALLOW = join(" ",
              [
                "*.amazonaws.com",
                "*.s3-us-gov-west-1.amazonaws.com",
                "*.drupal.org",
                "*.github.com",
                "*.packagist.org",
                "*.newrelic.com",
                "*.githubusercontent.com"
              ]
            )

            ## List of domains that applications are denied to connect to.
            PROXY_DENY = join(" ",
              [
                "*.yahoo.com"
              ]
            )

          }
          ## How long until the health check times out.
          health_check_timeout = 180

          ## The type of health check.
          health_check_type = "port"

          ## The number of instances to deploy.
          instances = 1

          ## How to tag the application.
          labels = {
            environment = terraform.workspace
          }

          ## The ammount of memory, in MB, should the applcation use.
          memory = 64

          ## The port the application should listen on.
          port = 8080

          ## Is the application routable from the internet?
          public_route = false

          ## The source file should be a directory or a zip file.
          source = "./applications/caddy-proxy"

          ## Templates take templated files and fill them in with sensitive data.
          ## The Caddyfile has the proxy username and password written to it during
          ## the 'terraform apply' command, before it the files are zipped up and 
          ## uploaded to cloud.gov.
          templates = [
            {
              source      = "${path.cwd}/applications/caddy-proxy/Caddyfile.tmpl"
              destination = "${path.cwd}/applications/caddy-proxy/Caddyfile"
            }
          ]
        }
      }

      ## Variables that are globally used in every space.
      circleci_variables = {
        caddy = {
          global = true
          variables = [
            "proxy_name",
            "proxy_port",
            "proxy_space",
            "caddy_internal_endpoint"
          ]
        }
      }
    }

    #################################
    ##
    ##    ____             
    ##   |  _ \  _____   __
    ##   | | | |/ _ \ \ / /
    ##   | |_| |  __/\ V / 
    ##   |____/ \___| \_/                 
    ##
    #################################              

    dev = merge(
      {
        ## Applications to deploy.
        apps = {
          waf = local.globals.apps.waf
        }
        services = {
          mysql   = local.globals.services.mysql
          secrets = local.globals.services.secrets
          static  = local.globals.services.static
          storage = local.globals.services.storage
        }
        circleci_variables = local.globals.circleci_variables
      },
      {
        ## The space to deploy to the application to.
        space = "${local.project}-dev"

        ## Passwords that need to be generated for this environment.
        ## These will actually use the sha256 result from the random module.
        passwords = {
          hash_salt = {
            length = 32
          }
          cron_key = {
            length = 32
          }
        }
      }
    )

    #################################
    ##
    ##  ____                _ 
    ## |  _ \ _ __ ___   __| |
    ## | |_) | '__/ _ \ / _` |
    ## |  __/| | | (_) | (_| |
    ## |_|   |_|  \___/ \__,_|
    ##
    #################################


    prod = merge(
      {
        ## Applications to deploy.
        apps = {
          waf = merge(
            local.globals.apps.waf,
            {
              instances = 2
            }
          )
        }
        services = {
          mysql   = local.globals.services.mysql
          secrets = local.globals.services.secrets
          static  = local.globals.services.static
          storage = local.globals.services.storage
        }
        circleci_variables = local.globals.circleci_variables
      },
      {
        ## The space to deploy to the application to.
        space = "${local.project}-${terraform.workspace}"

        ## Passwords that need to be generated for this environment.
        ## These will actually use the sha256 result from the random module.
        passwords = {
          hash_salt = {
            length = 32
          }
          cron_key = {
            length = 32
          }
        }
      }
    )

    #################################
    ##
    ##   ____  _                   
    ## / ___|| |_ __ _  __ _  ___ 
    ## \___ \| __/ _` |/ _` |/ _ \
    ##  ___) | || (_| | (_| |  __/
    ## |____/ \__\__,_|\__, |\___|
    ##                 |___/      
    ##
    #################################

    stage = merge(
      {
        ## Applications to deploy.
        apps = {
          waf = merge(
            local.globals.apps.waf,
            {
              instances = 2
            }
          )
        }
        services = {
          mysql   = local.globals.services.mysql
          secrets = local.globals.services.secrets
          static  = local.globals.services.static
          storage = local.globals.services.storage
        }
        circleci_variables = local.globals.circleci_variables
      },
      {
        ## Passwords that need to be generated for this environment.
        ## These will actually use the sha256 result from the random module.
        passwords = {
          hash_salt = {
            length = 32
          }
          cron_key = {
            length = 32
          }
        }
      }
    )

    #################################
    ##
    ##  _____         _   
    ## |_   _|__  ___| |_ 
    ##   | |/ _ \/ __| __|
    ##   | |  __/\__ \ |_ 
    ##   |_|\___||___/\__|
    ##                    
    #################################

    test = merge(
      {
        ## Applications to deploy.
        apps = {
          waf = local.globals.apps.waf
        }
        services = {
          mysql   = local.globals.services.mysql
          secrets = local.globals.services.secrets
          static  = local.globals.services.static
          storage = local.globals.services.storage
        }
        circleci_variables = local.globals.circleci_variables
      },
      {
        ## The space to deploy to the application to.
        space = "${local.project}-dev"

        ## Passwords that need to be generated for this environment.
        ## These will actually use the sha256 result from the random module.
        passwords = {
          hash_salt = {
            length = 32
          }
          cron_key = {
            length = 32
          }
        }
      }
    )
  }

  ## Map of the 'all' environement and the current workspace settings.
  env = merge(try(local.envs.all, {}), try(local.envs[terraform.workspace], {}))
}
