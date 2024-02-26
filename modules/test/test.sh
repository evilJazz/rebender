test_name="A Test plugin"
test_description="This is a short description."

test_usage()
{
    echo "This is a test module. It provides a generic example of how to delevop a module."
    echo

}

test_checkConfig()
{
    echo "test: checking config"
}

test_action()
{
    echo "test: Hello World!"
    echo "Doing something for 12 seconds..."
    sleep 12
    echo "Done."
}
