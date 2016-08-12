require "./libOpenCL"

module CrOpenCL

  enum DeviceTypes
    CPU = 2
    GPU = 4
    Accelerator = 8
    Default = 1
    All = -1

    def to_unsafe
      to_i64
    end
  end

  enum DeviceParameters
    Name = 4139
    DeviceVersion = 4143
    DriverVersion = 4141
    OpenCLVersion = 4157
    MaxComputeUnits = 4098

    def to_unsafe
      to_i64
    end
  end

  class Device

    @id : LibOpenCL::DeviceID
    @name = ""
    @hardware_version = ""
    @software_version = ""
    @c_version = ""
    @max_compute_units : UInt32

    def initialize(id : UInt64)
      @id = id.as(LibOpenCL::DeviceID)

      max_compute_units = uninitialized UInt32
      err = LibOpenCL.clGetDeviceInfo(@id, DeviceParameters::MaxComputeUnits, sizeof(UInt32), pointerof(max_compute_units), nil)
      raise CLError.new("clGetDeviceInfo failed.") unless err == CL_SUCCESS
      @max_compute_units = max_compute_units

      @name = get_info_string(DeviceParameters::Name)
      @hardware_version = get_info_string(DeviceParameters::DeviceVersion)
      @software_version = get_info_string(DeviceParameters::DriverVersion)
      @c_version = get_info_string(DeviceParameters::OpenCLVersion)
    end

    private def get_info_string(param : DeviceParameters)
      # Get the size of the C string to be returned from OpenCL
      err = LibOpenCL.clGetDeviceInfo(@id, param, 0, nil, out size)
      raise CLError.new("clGetDeviceInfo failed.") unless err == CL_SUCCESS

      # Allocate a buffer large enough to hold the string
      str = Slice(UInt8).new(size)
      # Get the value from OpenCL
      err = LibOpenCL.clGetDeviceInfo(@id, param, size, str, nil)
      raise CLError.new("clGetDeviceInfo failed.") unless err == CL_SUCCESS
      # C strings are null terminated, Crystal's are not: remove the last character (null terminator)
      # Sometimes the string from OpenCL ends in a space. Strip it away
      return String.new(str[0, size-1]).strip
    end

    def to_unsafe
      @id
    end

    def self.all(device_type = DeviceTypes::All)
      # Get devices on platform 0
      # TODO: support more platforms
      err = LibOpenCL.clGetDeviceIDs(0.to_u64.as(LibOpenCL::PlatformID), device_type.to_i64, 0, nil, out num_devices)
      raise CLError.new("clGetDeviceIDs failed.") unless err == CL_SUCCESS

      device_ids = Slice(UInt64).new(num_devices)

      err = LibOpenCL.clGetDeviceIDs(0.to_u64.as(LibOpenCL::PlatformID), device_type.to_i64, num_devices, device_ids, nil)
      raise CLError.new("clGetDeviceIDs failed.") unless err == CL_SUCCESS

      device_ids.map {|id| new(id) }
    end
  end
end