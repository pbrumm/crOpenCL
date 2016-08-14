require "./libOpenCL.cr"

module CrOpenCL

  enum KernelParams
    WorkGroupSize = 4528

    def to_unsafe
      to_i64
    end
  end

  class Kernel

    def initialize(@program : Program, @name : String)
      @kernel = LibOpenCL.clCreateKernel(@program, @name, out err)
      raise CLError.new("clCreateKernel failed.") unless err == CL_SUCCESS
    end

    def set_argument(index : Int32, value)
      val = value.responds_to?(:to_unsafe) ? value.to_unsafe : value
      err = LibOpenCL.clSetKernelArg(@kernel, index, sizeof(typeof(value)), pointerof(val))
      raise CLError.new("clSetKernelArg failed.") unless err == CL_SUCCESS
    end

    def to_unsafe
      @kernel
    end

    def finalize
      LibOpenCL.clReleaseKernel(@kernel)
    end

    def enqueue(queue : CommandQueue, *, global_work_size : Int32, local_work_size : Int32)
      lws = local_work_size.to_u64
      gws = global_work_size.to_u64
      # TODO add support for different dimensions, event wait lists & events
      err = LibOpenCL.clEnqueueNDRangeKernel(queue, @kernel, 1, nil, pointerof(gws), pointerof(lws), 0, nil, nil)
      raise CLError.new("clEnqueueNDRangeKernel failed.") unless err == CL_SUCCESS
    end

    def get_work_group_info(param_name : KernelParams)
      # Note: Some other params may have a size different that that of UInt64
      value = uninitialized UInt64
      err = LibOpenCL.clGetKernelWorkGroupInfo(@kernel, @program.device, param_name, sizeof(typeof(value)), pointerof(value), nil)
      raise CLError.new("clGetKernelWorkGroupInfo failed.") unless err == CL_SUCCESS
      return value
    end

    # method_missing seems to be the only way to get a macro as a method with AST arguments
    macro method_missing(call)
      {% if call.name == "set_arguments" %}
        {% for arg, index in call.args %}
          set_argument({{index}}, {{arg}})
        {% end %}
      {% else %}
        # TODO Find a way to get the source line and file in the error message
        {{ raise "Invalid kernel method: " + call.name.stringify }}
      {% end %}
    end
  end
end
