defmodule StorexTest.Browser.Handler do
  def init(request, state) do
    {:ok, file} = File.read("./test/browser_test/browser_test.html")

    request =
      :cowboy_req.reply(
        200,
        %{
          "content-type" => "text/html"
        },
        file,
        request
      )

    {:ok, request, state}
  end
end
