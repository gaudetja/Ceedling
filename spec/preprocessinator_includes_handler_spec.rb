require 'spec_helper'
require 'ceedling/preprocessinator_includes_handler'

describe PreprocessinatorIncludesHandler do
  before :each do
    @configurator    = double('configurator')
    @tool_executor   = double('tool_executor')
    @task_invoker    = double('task_invoker')
    @file_path_utils = double('file_path_utils')
    @yaml_wrapper    = double('yaml_wrapper')
    @file_wrapper    = double('file_wrapper')
  end

  subject do
    PreprocessinatorIncludesHandler.new(
      :configurator    => @configurator,
      :tool_executor   => @tool_executor,
      :task_invoker    => @task_invoker,
      :file_path_utils => @file_path_utils,
      :yaml_wrapper    => @yaml_wrapper,
      :file_wrapper    => @file_wrapper,
    )
  end

  context 'invoke_shallow_includes_list' do
    it 'should invoke the rake task which will build included files' do
      # create test state/variables
      # mocks/stubs/expected calls
      inc_list_double = double('inc-list-double')
      expect(@file_path_utils).to receive(:form_preprocessed_includes_list_filepath).with('some_source_file.c').and_return(inc_list_double)
      expect(@task_invoker).to receive(:invoke_test_shallow_include_lists).with( [inc_list_double] )
      # execute method
      subject.invoke_shallow_includes_list('some_source_file.c')
      # validate results
    end
  end

  context 'form_shallow_dependencies_rule' do
    it 'should return an annotated dependency rule generated by the preprocessor' do
      # create test state/variables
      # mocks/stubs/expected calls
      expect(@file_path_utils).to receive(:form_temp_path).with('some_source_file.c','_').and_return('_some_source_file.c')
      contents_double = double('contents-double')
      expect(@file_wrapper).to receive(:read).with('some_source_file.c').and_return(contents_double)
      expect(contents_double).to receive(:valid_encoding?).and_return(true)
      expect(contents_double).to receive(:gsub!).with(/^\s*#include\s+[\"<]\s*(\S+)\s*[\">]/, "#include \"\\1\"\n#include \"@@@@\\1\"")
      expect(contents_double).to receive(:gsub!).with(/^\s*TEST_FILE\(\s*\"\s*(\S+)\s*\"\s*\)/, "#include \"\\1\"\n#include \"@@@@\\1\"")
      expect(@file_wrapper).to receive(:write).with('_some_source_file.c', contents_double)
      expect(@configurator).to receive(:tools_test_includes_preprocessor).and_return('cpp')
      command_double = double('command-double')
      expect(@tool_executor).to receive(:build_command_line).with('cpp', [], '_some_source_file.c').and_return(command_double)
      expect(command_double).to receive(:[]).with(:line).and_return('cpp')
      expect(command_double).to receive(:[]).with(:options).and_return(['arg1','arg2'])
      output_double = double('output-double')
      expect(@tool_executor).to receive(:exec).with('cpp',['arg1','arg2']).and_return(output_double)
      expect(output_double).to receive(:[]).with(:output).and_return('make-rule').twice()
      # execute method
      results = subject.form_shallow_dependencies_rule('some_source_file.c')
      # validate results
      expect(results).to eq 'make-rule'
    end
  end

  context 'extract_includes_helper' do
    it 'should return the list of direct dependencies for the given test file' do
      # create test state/variables
      # mocks/stubs/expected calls
      expect(@configurator).to receive(:extension_header).and_return('.h')
      expect(@configurator).to receive(:extension_source).and_return('.c')
      expect(@configurator).to receive(:tools_test_includes_preprocessor)
      expect(@configurator).to receive(:project_config_hash).and_return({ })
      expect(@file_path_utils).to receive(:form_temp_path).and_return("/_dummy_file.c")
      expect(@file_wrapper).to receive(:read).and_return("")
      expect(@file_wrapper).to receive(:write)
      expect(@tool_executor).to receive(:build_command_line).and_return({:line => "", :options => ""})
      expect(@tool_executor).to receive(:exec).and_return({ :output => %q{
        _test_DUMMY.o: Build/temp/_test_DUMMY.c \
          source/some_header1.h \
          source/some_lib/some_header2.h \
          source/some_other_lib/some_header2.h \
          @@@@some_header1.h \
          @@@@some_lib/some_header2.h \
          @@@@some_other_lib/some_header2.h
      }})
      # execute method
      results = subject.extract_includes_helper("/dummy_file_1.c", [], [], [])
      # validate results
      expect(results).to eq [
        ['source/some_header1.h',
          'source/some_lib/some_header2.h',
          'source/some_other_lib/some_header2.h'],
        [], []
      ]
    end

    it 'should correctly handle path separators' do
      # create test state/variables
      # mocks/stubs/expected calls
      expect(@configurator).to receive(:extension_header).and_return('.h')
      expect(@configurator).to receive(:extension_source).and_return('.c')
      expect(@configurator).to receive(:tools_test_includes_preprocessor)
      expect(@configurator).to receive(:project_config_hash).and_return({ })
      expect(@file_path_utils).to receive(:form_temp_path).and_return("/_dummy_file.c")
      expect(@file_wrapper).to receive(:read).and_return("")
      expect(@file_wrapper).to receive(:write)
      expect(@tool_executor).to receive(:build_command_line).and_return({:line => "", :options => ""})
      expect(@tool_executor).to receive(:exec).and_return({ :output => %q{
        _test_DUMMY.o: Build/temp/_test_DUMMY.c \
          source\some_header1.h \
          source\some_lib\some_header2.h \
          source\some_lib1\some_lib\some_header2.h \
          source\some_other_lib\some_header2.h \
          @@@@some_header1.h \
          @@@@some_lib/some_header2.h \
          @@@@some_lib1/some_lib/some_header2.h \
          @@@@some_other_lib/some_header2.h
      }})
      # execute method
      results = subject.extract_includes_helper("/dummy_file_2.c", [], [], [])
      # validate results
      expect(results).to eq [
        ['source/some_header1.h',
          'source/some_lib/some_header2.h',
          'source/some_lib1/some_lib/some_header2.h',
          'source/some_other_lib/some_header2.h'],
        [], []
      ]
    end

    it 'exclude annotated headers with no matching "real" header' do
      # create test state/variables
      # mocks/stubs/expected calls
      expect(@configurator).to receive(:extension_header).and_return('.h')
      expect(@configurator).to receive(:extension_source).and_return('.c')
      expect(@configurator).to receive(:tools_test_includes_preprocessor)
      expect(@configurator).to receive(:project_config_hash).and_return({ })
      expect(@file_path_utils).to receive(:form_temp_path).and_return("/_dummy_file.c")
      expect(@file_wrapper).to receive(:read).and_return("")
      expect(@file_wrapper).to receive(:write)
      expect(@tool_executor).to receive(:build_command_line).and_return({:line => "", :options => ""})
      expect(@tool_executor).to receive(:exec).and_return({ :output => %q{
        _test_DUMMY.o: Build/temp/_test_DUMMY.c \
          source/some_header1.h \
          @@@@some_header1.h \
          @@@@some_lib/some_header2.h
      }})
      # execute method
      results = subject.extract_includes_helper("/dummy_file_3.c", [], [], [])
      # validate results
      expect(results).to eq [
        ['source/some_header1.h'],
        [], []
      ]
    end

    it 'should correctly filter secondary dependencies' do
      # create test state/variables
      # mocks/stubs/expected calls
      expect(@configurator).to receive(:extension_header).and_return('.h')
      expect(@configurator).to receive(:extension_source).and_return('.c')
      expect(@configurator).to receive(:tools_test_includes_preprocessor)
      expect(@configurator).to receive(:project_config_hash).and_return({ })
      expect(@file_path_utils).to receive(:form_temp_path).and_return("/_dummy_file.c")
      expect(@file_wrapper).to receive(:read).and_return("")
      expect(@file_wrapper).to receive(:write)
      expect(@tool_executor).to receive(:build_command_line).and_return({:line => "", :options => ""})
      expect(@tool_executor).to receive(:exec).and_return({ :output => %q{
        _test_DUMMY.o: Build/temp/_test_DUMMY.c \
          source\some_header1.h \
          source\some_lib\some_header2.h \
          source\some_lib1\some_lib\some_header2.h \
          source\some_other_lib\some_header2.h \
          source\some_other_lib\another.h \
          @@@@some_header1.h \
          @@@@some_lib/some_header2.h \
          @@@@lib/some_header2.h \
          @@@@some_other_lib/some_header2.h
      }})
      # execute method
      results = subject.extract_includes_helper("/dummy_file_4.c", [], [], [])
      # validate results
      expect(results).to eq [
        ['source/some_header1.h',
          'source/some_lib/some_header2.h',
          'source/some_other_lib/some_header2.h'],
        [], []
      ]
    end
  end

  context 'invoke_shallow_includes_list' do
    it 'should invoke the rake task which will build included files' do
      # create test state/variables
      # mocks/stubs/expected calls
      expect(@yaml_wrapper).to receive(:dump).with('some_source_file.c', [])
      # execute method
      subject.write_shallow_includes_list('some_source_file.c', [])
      # validate results
    end
  end
end
