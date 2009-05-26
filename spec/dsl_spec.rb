require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class MyScript < Thor
  group :script
  default_task :example_default_task

  map "-T" => :animal, ["-f", "--foo"] => :foo

  desc "zoo", "zoo around"
  def zoo
    true
  end

  desc "animal TYPE", "horse around"
  def animal(type)
    [type]
  end

  desc "foo BAR", <<END
do some fooing
  This is more info!
  Everyone likes more info!
END
  method_options :force => :boolean
  def foo(bar)
    [bar, options]
  end

  desc "example_default_task", "example!"
  def example_default_task
    "default task"
  end
end

class MyChildScript < MyScript
  method_options :force => :boolean, :param => :numeric
  def initialize(*args)
    super
  end

  desc "zoo", "zoo around"
  method_options :param => :required
  def zoo
    options
  end

  desc "animal TYPE", "horse around"
  method_options :other => :optional
  def animal(type)
    [type, options]
  end
end

module Scripts
  class MyGrandChildScript < MyChildScript
    default_options :force => :optional, :param => :required
  end
end

class Amazing
  desc "hello", "say hello"
  def hello
    puts "Hello"
  end
end

describe Thor::DSL do
  describe "#default_task" do
    it "sets a default task" do
      MyScript.default_task.must == "example_default_task"
    end

    it "invokes the default task if no command is specified" do
      MyScript.start([]).must == "default task"
    end

    it "inherits the default task from parent" do
      MyChildScript.default_task.must == "example_default_task"
    end
  end

  describe "#map" do
    it "calls the alias of a method if one is provided" do
      MyScript.start(["-T", "fish"]).must == ["fish"]
    end

    it "calls the alias of a method if several are provided via .map" do
      MyScript.start(["-f", "fish"]).must == ["fish", {}]
      MyScript.start(["--foo", "fish"]).must == ["fish", {}]
    end

    it "inherits all mappings from parent" do
      MyChildScript.default_task.must == "example_default_task"
    end
  end

  describe "#desc" do
    before(:all) do
      @content = capture(:stdout) { MyScript.start(["help"]) }
    end

    it "provides useful help info for the help method itself" do
      @content.must =~ /help \[TASK\] +describe available tasks/
    end

    it "provides useful help info for a simple method" do
      @content.must =~ /zoo +zoo around/
    end

    it "provides useful help info for a method with params" do
      @content.must =~ /animal TYPE +horse around/
    end

    it "provides useful help info for a method with options" do
      @content.must =~ /foo BAR \[\-\-force\] +do some fooing/
    end

    it "provides full help info when talking about a specific task" do
      capture(:stdout) { MyScript.start(["help", "foo"]) }.must == <<END
foo BAR [--force]
do some fooing
  This is more info!
  Everyone likes more info!
END
    end
  end

  describe "#group" do
    it "sets a group name" do
      MyScript.group_name.must == "script"
    end

    it "inherits the group name from parent" do
      MyChildScript.group_name.must == "script"
    end

    it "defaults to standard if no group name is given" do
      Amazing.group_name.must == "standard"
    end
  end

  describe "#method_options" do
    it "sets default options if called before an initializer" do
      MyChildScript.opts.must == { :force => :boolean, :param => :numeric }
    end

    it "overwrites default options if called on the method scope" do
      args = ["zoo", "--force", "--param", "feathers"]
      options = MyChildScript.start(args)
      options.must == { "force" => true, "param" => "feathers" }
    end

    it "allows default options to be merged with method options" do
      args = ["animal", "bird", "--force", "--param", "1.0", "--other", "tweets"]
      arg, options = MyChildScript.start(args)
      arg.must == 'bird'
      options.must == { "force"=>true, "param"=>1.0, "other"=>"tweets" }
    end
  end

  describe "#default_options" do
    it "sets default options overwriting superclass definitions" do
      Scripts::MyGrandChildScript.opts.must == { :force=>:optional, :param=>:required }
    end
  end

  describe "#subclasses" do
    it "tracks its subclasses in an Array" do
      Thor.subclasses.must include(MyScript)
      Thor.subclasses.must include(MyChildScript)
      Thor.subclasses.must include(Scripts::MyGrandChildScript)

      MyChildScript.subclasses.must include(Scripts::MyGrandChildScript)
      MyChildScript.subclasses.must_not include(MyScript)
    end
  end

  describe "#subclass_files" do
    it "returns tracked subclasses, grouped by the files they come from" do
      Thor.subclass_files[File.expand_path(__FILE__)].must == [ MyScript, MyChildScript, Scripts::MyGrandChildScript, Amazing ]
    end

    it "tracks a single subclass across multiple files" do
      thorfile = File.join(File.dirname(__FILE__), "fixtures", "task.thor")
      Thor.subclass_files[File.expand_path(thorfile)].must include(Amazing)
      Thor.subclass_files[File.expand_path(__FILE__)].must include(Amazing)
    end
  end

  describe "#[]" do
    it "retrieves an specific task object" do
      MyScript[:foo].class.must == Thor::Task
      MyChildScript[:foo].class.must == Thor::Task
      Scripts::MyGrandChildScript[:foo].class.must == Thor::Task
    end

    xit "returns a dynamic task to allow method missing invocation" do
      MyScript[:none].class.must == Thor::Task
      MyScript[:none].description =~ /dynamic/
    end
  end
end