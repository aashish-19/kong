local helpers = require "spec.helpers"

describe("#wasm declarative config", function()
  local client
  local filter_names

  lazy_setup(function()
    assert(helpers.start_kong({
      database = "off",
      nginx_conf = "spec/fixtures/custom_nginx.template",
      wasm = true,
    }))

    client = helpers.admin_client()

    do
      local res = client:get("/")
      assert.response(res).has.status(200)
      local json = assert.response(res).has.jsonbody()
      assert.is_table(json.configuration)
      assert.is_table(json.configuration.wasm_modules_parsed)
      local filters = {}

      for _, item in ipairs(json.configuration.wasm_modules_parsed) do
        assert.is_table(item)
        assert.is_string(item.name)
        table.insert(filters, item.name)
      end
      filter_names = table.concat(filters, ", ")
    end
  end)

  lazy_teardown(function()
    if client then client:close() end
    helpers.stop_kong(nil, true)
  end)

  local function post_config(config)
    config._format_version = config._format_version or "3.0"

    local res = client:post("/config?flatten_errors=1", {
      body = config,
      headers = {
        ["Content-Type"] = "application/json"
      },
    })

    assert.response(res).has.jsonbody()

    assert.logfile().has.no.line("[emerg]", true, 0)
    assert.logfile().has.no.line("[crit]",  true, 0)
    assert.logfile().has.no.line("[alert]", true, 0)
    assert.logfile().has.no.line("[error]", true, 0)
    assert.logfile().has.no.line("[warn]",  true, 0)

    return res
  end

  it("rejects filter chains with non-existent filters", function()
    local res = post_config({
      services = {
        { name = "test",
          url = "http://wasm.test/",
          filter_chains = {
            { name = "test",
              filters = {
                { name = "i_do_not_exist" }
              },
            },
          },
        },
      },
    })

    assert.response(res).has.status(400)

    local json = assert.response(res).has.jsonbody()

    assert.is_table(json.flattened_errors)

    assert.same(1, #json.flattened_errors)
    assert.is_table(json.flattened_errors[1])

    assert.is_table(json.flattened_errors[1].errors)
    assert.same(1, #json.flattened_errors[1].errors)

    local err = assert.is_table(json.flattened_errors[1].errors[1])

    assert.same("filters.1.name", err.field)
    assert.same("field", err.type)
    assert.matches("expected one of: ", err.message)
    assert.matches(filter_names, err.message)
  end)
end)

describe("#wasm declarative config (wasm = off)", function()
  local client

  lazy_setup(function()
    assert(helpers.start_kong({
      database = "off",
      nginx_conf = "spec/fixtures/custom_nginx.template",
      wasm = "off",
    }))

    client = helpers.admin_client()
  end)

  lazy_teardown(function()
    if client then client:close() end
    helpers.stop_kong(nil, true)
  end)

  local function post_config(config)
    config._format_version = config._format_version or "3.0"

    local res = client:post("/config?flatten_errors=1", {
      body = config,
      headers = {
        ["Content-Type"] = "application/json"
      },
    })

    assert.response(res).has.jsonbody()

    assert.logfile().has.no.line("[emerg]", true, 0)
    assert.logfile().has.no.line("[crit]",  true, 0)
    assert.logfile().has.no.line("[alert]", true, 0)
    assert.logfile().has.no.line("[error]", true, 0)
    assert.logfile().has.no.line("[warn]",  true, 0)

    return res
  end

  it("rejects filter chains with non-existent filters", function()
    local res = post_config({
      services = {
        { name = "test",
          url = "http://wasm.test/",
          filter_chains = {
            { name = "test",
              filters = {
                { name = "i_do_not_exist" }
              },
            },
          },
        },
      },
    })

    assert.response(res).has.status(400)

    local json = assert.response(res).has.jsonbody()
    helpers.intercept(json)

    assert.is_table(json.flattened_errors)

    assert.same(1, #json.flattened_errors)
    assert.is_table(json.flattened_errors[1])

    assert.is_table(json.flattened_errors[1].errors)
    assert.same(1, #json.flattened_errors[1].errors)

    local err = assert.is_table(json.flattened_errors[1].errors[1])

    assert.same("filters.1.name", err.field)
    assert.same("field", err.type)
    assert.matches("expected one of: ", err.message)
  end)
end)
