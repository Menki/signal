require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Project do
  should_validate_presence_of :name, :url, :email
  should_have_many :builds
  should_have_many :deploys

  it "should have public/projects as the projects base path" do
    Project::BASE_PATH.should eql("#{RAILS_ROOT}/public/projects")
  end

  it "should have default build_command as 'rake build'" do
    subject.build_command.should eql("rake build")
  end

  context "on creation" do
    before :each do
      success_on_command
      @project = Project.new :name => "social", :url => "git://social", :email => "fake@mouseoverstudio.com"
    end

    it "should clone a repository without the history" do
      expect_for "cd #{Project::BASE_PATH} && git clone --depth 1 #{@project.url} #{@project.name}"
      @project.save
    end

    it "should checkout the configured branch if different from master" do
      @project.branch = branch = "integration"
      expect_for "cd #{@project.send :path} && git checkout -b #{branch} origin/#{branch} > #{@project.send :log_path} 2>&1"
      @project.save
    end

    it "should dont checkout the configured branch if it's master" do
      branch = @project.branch
      dont_accept "cd #{@project.send :path} && git checkout -b #{branch} origin/#{branch} > #{@project.send :log_path} 2>&1"
      @project.save
    end
    
    it "should create a gemset with the project name" do
      expect_for "cd #{@project.send :path} && rvm gemset create #{@project.name} >> #{@project.send :log_path} 2>&1"
      @project.save
    end

    it "should run inploy:local:setup" do
      expect_for "cd #{@project.send :path} && rake inploy:local:setup >> #{@project.send :log_path} 2>&1"
      @project.save
    end
  end

  context "on #build" do
    let(:project) { create_project }

    it "should create a new build" do
      project.builds.should_receive(:create)
      project.build
    end

    it "should set the project as building while building" do
      project.builds.should_receive(:create) do
        Project.last.should be_building
      end
      project.build
    end
  end

  context "when returing the status" do
    before :each do
      @project = Project.new :builds => [@build = Build.new]
    end

    it "should return #{Build::SUCCESS} when the last build was successful" do
      @build.success = true
      @project.status.should eql(Build::SUCCESS)
    end

    it "should return #{Build::FAIL} when the last build was not successful" do
      @build.success = false
      @project.status.should eql(Build::FAIL)
    end

    it "should return #{Project::BUILDING} when the build is running" do
      @project.building = true
      @project.status.should eql(Project::BUILDING)
    end

    it "should return nil when there are no builds" do
      @project.builds = []
      @project.status.should be_nil
    end
  end

  it "should return when was the last build" do
    date = Time.now
    Project.new(:builds => [Build.new :created_at => date]).last_builded_at.should eql(date)
  end

  context "on update" do
    before :each do
      success_on_command
      @project = Project.create! :name => "project1",:url => "git://social", :email => "fake@mouseoverstudio.com"
    end

    it "should rename the directory when the name changes" do
      expect_for "cd #{Project::BASE_PATH} && mv project1 project2"
      @project.update_attributes :name => "project2"
    end

    it "should not rename the directory when the name doesn't change" do
      dont_accept "cd #{Project::BASE_PATH} && mv project1 project1"
      @project.update_attributes :email => "fak2@faker.com"
    end
  end

  it "should return nil as last build date when no builds exists" do
    Project.new.last_builded_at.should be_nil
  end

  it "should have name as a friendly_id" do
    name = "rails"
    Project.new(:name => name).friendly_id.should eql(name)
  end

  it "should deploy the project creating a new deploy" do
    project = Project.new
    project.deploys.should_receive(:create)
    project.deploy
  end

  it "should use master as the default branch" do
    subject.branch.should eql("master")
  end

  context "on has_file?" do
    it "should return true if the project has the file path" do
      file_exists(subject.send(:path) + '/doc/specs.html')
      subject.has_file?("doc/specs.html").should be_true
    end

    it "should return false if the project doesnt has the file path" do
      file_doesnt_exists(subject.send(:path) + '/doc/specs.html')
      subject.has_file?("doc/specs.html").should be_false
    end
  end
end
