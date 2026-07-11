RSpec.describe Ready::Configuration do
  around do |example|
    original = ENV.to_h
    begin
      example.run
    ensure
      ENV.replace(original)
    end
  end

  describe "#prefix" do
    it "reads the READY_PREFIX environment variable" do
      ENV["READY_PREFIX"] = "/tmp/custom-ready"
      expect(subject.prefix.to_s).to eq("/tmp/custom-ready")
    end

    it "defaults to /tmp/ready" do
      ENV.delete("READY_PREFIX")
      expect(subject.prefix.to_s).to eq("/tmp/ready")
    end
  end

  describe "#sock_path" do
    it "defaults to a socket under the prefix" do
      ENV.delete("READY_SOCK_PATH")
      ENV["READY_PREFIX"] = "/tmp/custom-ready"
      expect(subject.sock_path.to_s).to eq("/tmp/custom-ready/ready.sock")
    end
  end
end
