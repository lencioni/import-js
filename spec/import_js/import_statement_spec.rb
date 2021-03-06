require 'spec_helper'

describe ImportJS::ImportStatement do
  describe '.parse' do
    let(:string) { "const foo = require('foo');" }
    subject { described_class.parse(string) }

    context 'when the string is a valid es6 import' do
      let(:string) { "import foo from 'foo';" }

      it 'returns a valid ImportStatement instance' do
        expect(subject.assignment).to eq('foo')
        expect(subject.path).to eq('foo')
      end

      context 'and it has line breaks' do
        let(:string) { "import foo\n  from 'foo';" }

        it 'returns a valid ImportStatement instance' do
          expect(subject.assignment).to eq('foo')
          expect(subject.path).to eq('foo')
        end
      end

      context 'and it uses named imports' do
        let(:string) { "import { foo } from 'foo';" }

        it 'returns a valid ImportStatement instance' do
          expect(subject.assignment).to eq('{ foo }')
          expect(subject.path).to eq('foo')
          expect(subject.named_imports?).to be_truthy
          expect(subject.default_import).to eq(nil)
          expect(subject.named_imports).to eq(['foo'])
        end

        context 'and it has line breaks' do
          let(:string) { "import {\n  foo,\n  bar,\n} from 'foo';" }

          it 'returns a valid ImportStatement instance' do
            expect(subject.assignment).to eq("{\n  foo,\n  bar,\n}")
            expect(subject.path).to eq('foo')
            expect(subject.named_imports?).to be_truthy
            expect(subject.default_import).to eq(nil)
            expect(subject.named_imports).to eq(%w[foo bar])
          end
        end
      end

      context 'and it has default and a named import' do
        let(:string) { "import foo, { bar } from 'foo';" }

        it 'returns a valid ImportStatement instance' do
          expect(subject.assignment).to eq('foo, { bar }')
          expect(subject.path).to eq('foo')
          expect(subject.named_imports?).to be_truthy
          expect(subject.default_import).to eq('foo')
          expect(subject.named_imports).to eq(['bar'])
        end

        context 'and it has line breaks' do
          let(:string) { "import foo, {\n  bar,\n  baz,\n} from 'foo';" }

          it 'returns a valid ImportStatement instance' do
            expect(subject.assignment).to eq("foo, {\n  bar,\n  baz,\n}")
            expect(subject.path).to eq('foo')
            expect(subject.named_imports?).to be_truthy
            expect(subject.default_import).to eq('foo')
            expect(subject.named_imports).to eq(%w[bar baz])
          end
        end
      end
    end

    context 'when the string is a valid import using const' do
      it 'returns a valid ImportStatement instance' do
        expect(subject.assignment).to eq('foo')
        expect(subject.path).to eq('foo')
      end

      context 'and it has line breaks' do
        let(:string) { "const foo = \n  require('foo');" }

        it 'returns a valid ImportStatement instance' do
          expect(subject.assignment).to eq('foo')
          expect(subject.path).to eq('foo')
        end

        it 'is not named_imports?' do
          expect(subject.named_imports?).to be_falsy
        end
      end

      context 'and it is using a custom `import_function`' do
        let(:string) { "const foo = customRequire('foo');" }

        it 'returns a valid ImportStatement instance' do
          expect(subject.assignment).to eq('foo')
          expect(subject.path).to eq('foo')
        end
      end

      context 'and it has a destructured assignment' do
        let(:string) { "const { foo } = require('foo');" }

        it 'returns a valid ImportStatement instance' do
          expect(subject.assignment).to eq('{ foo }')
          expect(subject.path).to eq('foo')
          expect(subject.named_imports?).to be_truthy
          expect(subject.default_import).to eq(nil)
          expect(subject.named_imports).to eq(['foo'])
        end

        context 'and it has line breaks' do
          let(:string) { "const {\n  foo,\n  bar,\n} = require('foo');" }

          it 'returns a valid ImportStatement instance' do
            expect(subject.assignment).to eq("{\n  foo,\n  bar,\n}")
            expect(subject.path).to eq('foo')
            expect(subject.named_imports?).to be_truthy
            expect(subject.default_import).to eq(nil)
            expect(subject.named_imports).to eq(%w[foo bar])
          end
        end

        context 'injecting a new named import' do
          let(:injected_variable) { 'bar' }
          let(:statement) do
            statement = subject
            statement.inject_named_import(injected_variable)
            statement
          end

          it 'does not add a default_import' do
            expect(statement.default_import).to eq(nil)
          end

          it 'adds that variable and sorts the list' do
            expect(statement.named_imports).to eq(%w[bar foo])
          end

          it 'can reconstruct using `to_import_strings`' do
            statement.declaration_keyword = 'const'
            statement.import_function = 'require'
            expect(statement.to_import_strings(80, ' '))
              .to eq(["const { bar, foo } = require('foo');"])
          end

          context 'injecting a variable that is already in the list' do
            let(:injected_variable) { 'foo' }

            it 'does not add a default import' do
              expect(statement.default_import).to eq(nil)
            end

            it 'does not add a duplicate' do
              expect(statement.named_imports).to eq(['foo'])
            end
          end
        end
      end
    end

    context 'when the string is not a valid import' do
      let(:string) { 'var foo = bar.hello;' }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#named_imports?' do
    let(:import_statement) { described_class.new }
    let(:default_import) { nil }
    let(:named_imports) { nil }

    before do
      unless default_import.nil?
        import_statement.default_import = default_import
      end

      unless named_imports.nil?
        import_statement.named_imports = named_imports
      end
    end

    subject { import_statement.named_imports? }

    context 'without a default import or named imports' do
      it { should eq(false) }
    end

    context 'with a default import' do
      let(:default_import) { 'foo' }
      it { should eq(false) }

      context 'when default import is removed' do
        before { import_statement.delete_variable('foo') }
        it { should eq(false) }
      end
    end

    context 'with named imports' do
      let(:named_imports) { ['foo'] }
      it { should eq(true) }

      context 'when named imports are removed' do
        before { import_statement.delete_variable('foo') }
        it { should eq(false) }
      end
    end

    context 'with an empty array of named imports' do
      let(:named_imports) { [] }
      it { should eq(false) }
    end
  end

  describe '#empty?' do
    let(:import_statement) { described_class.new }
    let(:default_import) { nil }
    let(:named_imports) { nil }

    before do
      unless default_import.nil?
        import_statement.default_import = default_import
      end

      unless named_imports.nil?
        import_statement.named_imports = named_imports
      end
    end

    subject { import_statement.empty? }

    context 'without a default import or named imports' do
      it { should eq(true) }
    end

    context 'with a default import' do
      let(:default_import) { 'foo' }
      it { should eq(false) }

      context 'when default import is removed' do
        before { import_statement.delete_variable('foo') }
        it { should eq(true) }
      end
    end

    context 'with named imports' do
      let(:named_imports) { ['foo'] }
      it { should eq(false) }

      context 'when named imports are removed' do
        before { import_statement.delete_variable('foo') }
        it { should eq(true) }
      end
    end

    context 'with an empty array of named imports' do
      let(:named_imports) { [] }
      it { should eq(true) }
    end
  end

  describe '#merge' do
    let(:existing_import_statement) { described_class.new }
    let(:new_import_statement) { described_class.new }
    let(:existing_default_import) { nil }
    let(:existing_named_imports) { nil }
    let(:new_default_import) { nil }
    let(:new_named_imports) { nil }

    before do
      unless existing_default_import.nil?
        existing_import_statement.default_import = existing_default_import
      end

      unless existing_named_imports.nil?
        existing_import_statement.named_imports = existing_named_imports
      end

      unless new_default_import.nil?
        new_import_statement.default_import = new_default_import
      end

      unless new_named_imports.nil?
        new_import_statement.named_imports = new_named_imports
      end
    end

    subject do
      existing_import_statement.merge(new_import_statement)
      existing_import_statement
    end

    context 'without a new default import' do
      let(:existing_default_import) { 'foo' }

      it 'uses the existing default import' do
        expect(subject.default_import).to eq('foo')
      end
    end

    context 'without an existing default import' do
      let(:new_default_import) { 'foo' }

      it 'uses the new default import' do
        expect(subject.default_import).to eq('foo')
      end
    end

    context 'with both default imports' do
      let(:existing_default_import) { 'foo' }
      let(:new_default_import) { 'bar' }

      it 'uses the new default import' do
        expect(subject.default_import).to eq('bar')
      end
    end

    context 'without new named imports' do
      let(:existing_named_imports) { ['foo'] }

      it 'uses the existing named imports' do
        expect(subject.named_imports).to eq(['foo'])
      end
    end

    context 'without existing named imports' do
      let(:new_named_imports) { ['foo'] }

      it 'uses the new named imports' do
        expect(subject.named_imports).to eq(['foo'])
      end
    end

    context 'with both named imports' do
      let(:existing_named_imports) { ['foo'] }
      let(:new_named_imports) { ['bar'] }

      it 'uses the new named imports' do
        expect(subject.named_imports).to eq(%w[bar foo])
      end
    end

    context 'when the new named import is the same as the existing' do
      let(:existing_named_imports) { ['foo'] }
      let(:new_named_imports) { ['foo'] }

      it 'does not duplicate' do
        expect(subject.named_imports).to eq(['foo'])
      end
    end
  end

  describe '#to_import_strings' do
    let(:import_statement) { described_class.new }
    let(:import_function) { 'require' }
    let(:path) { 'path' }
    let(:default_import) { nil }
    let(:named_imports) { nil }
    let(:max_line_length) { 80 }
    let(:tab) { '  ' }

    before do
      import_statement.path = path

      unless default_import.nil?
        import_statement.default_import = default_import
      end

      unless named_imports.nil?
        import_statement.named_imports = named_imports
      end
    end

    subject do
      import_statement.declaration_keyword = declaration_keyword
      import_statement.import_function = import_function
      import_statement.to_import_strings(max_line_length, tab)
    end

    context 'with import declaration keyword' do
      let(:declaration_keyword) { 'import' }

      context 'with a default import' do
        let(:default_import) { 'foo' }
        it { should eq(["import foo from 'path';"]) }

        context 'with `import_function`' do
          let(:import_function) { 'myCustomRequire' }

          # `import_function` only applies to const/var
          it { should eq(["import foo from 'path';"]) }
        end

        context 'when longer than max line length' do
          let(:default_import) { 'ReallyReallyReallyReallyLong' }
          let(:path) { 'also_very_long_for_some_reason' }
          let(:max_line_length) { 50 }
          it { should eq(["import #{default_import} from\n  '#{path}';"]) }

          context 'with different tab' do
            let(:tab) { "\t" }
            it { should eq(["import #{default_import} from\n\t'#{path}';"]) }
          end
        end
      end

      context 'with named imports' do
        let(:named_imports) { %w[foo bar] }
        it { should eq(["import { foo, bar } from 'path';"]) }

        context 'when longer than max line length' do
          let(:named_imports) { %w[foo bar baz fizz buzz] }
          let(:path) { 'also_very_long_for_some_reason' }
          let(:max_line_length) { 50 }
          it do
            should eq(
              [
                "import {\n  foo,\n  bar,\n  baz,\n  fizz,\n  buzz,\n} " \
                "from '#{path}';",
              ]
            )
          end
        end
      end

      context 'with default and named imports' do
        let(:default_import) { 'foo' }
        let(:named_imports) { %w[bar baz] }
        it { should eq(["import foo, { bar, baz } from 'path';"]) }

        context 'when longer than max line length' do
          let(:named_imports) { %w[bar baz fizz buzz] }
          let(:path) { 'also_very_long_for_some_reason' }
          let(:max_line_length) { 50 }
          it do
            should eq(
              [
                "import foo, {\n  bar,\n  baz,\n  fizz,\n  buzz,\n} " \
                "from '#{path}';",
              ]
            )
          end
        end
      end
    end

    context 'with const declaration keyword' do
      let(:declaration_keyword) { 'const' }

      context 'with a default import' do
        let(:default_import) { 'foo' }
        it { should eq(["const foo = require('path');"]) }

        context 'with `import_function`' do
          let(:import_function) { 'myCustomRequire' }
          it { should eq(["const foo = myCustomRequire('path');"]) }
        end

        context 'when longer than max line length' do
          let(:default_import) { 'ReallyReallyReallyReallyLong' }
          let(:path) { 'also_very_long_for_some_reason' }
          let(:max_line_length) { 50 }
          it do
            should eq(["const #{default_import} =\n  require('#{path}');"])
          end

          context 'with different tab' do
            let(:tab) { "\t" }
            it do
              should eq(["const #{default_import} =\n\trequire('#{path}');"])
            end
          end
        end
      end

      context 'with named imports' do
        let(:named_imports) { %w[foo bar] }
        it { should eq(["const { foo, bar } = require('path');"]) }

        context 'with `import_function`' do
          let(:import_function) { 'myCustomRequire' }
          it { should eq(["const { foo, bar } = myCustomRequire('path');"]) }
        end

        context 'when longer than max line length' do
          let(:named_imports) { %w[foo bar baz fizz buzz] }
          let(:path) { 'also_very_long_for_some_reason' }
          let(:max_line_length) { 50 }
          it do
            should eq(
              [
                "const {\n  foo,\n  bar,\n  baz,\n  fizz,\n  buzz,\n} = " \
                "require('#{path}');",
              ]
            )
          end
        end
      end

      context 'with default and named imports' do
        let(:default_import) { 'foo' }
        let(:named_imports) { %w[bar baz] }
        it do
          should eq(
            [
              "const foo = require('path');",
              "const { bar, baz } = require('path');",
            ]
          )
        end

        context 'with `import_function`' do
          let(:import_function) { 'myCustomRequire' }
          it do
            should eq(
              [
                "const foo = myCustomRequire('path');",
                "const { bar, baz } = myCustomRequire('path');",
              ]
            )
          end
        end

        context 'when longer than max line length' do
          let(:named_imports) { %w[bar baz fizz buzz] }
          let(:path) { 'also_very_long_for_some_reason' }
          let(:max_line_length) { 50 }
          it do
            should eq(
              [
                "const foo =\n  require('#{path}');",
                "const {\n  bar,\n  baz,\n  fizz,\n  buzz,\n} = " \
                "require('#{path}');",
              ]
            )
          end
        end
      end
    end
  end
end
