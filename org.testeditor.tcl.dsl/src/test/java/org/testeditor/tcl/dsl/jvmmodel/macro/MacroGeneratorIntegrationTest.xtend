package org.testeditor.tcl.dsl.jvmmodel.macro

import org.junit.Before
import org.junit.Test
import org.testeditor.dsl.common.testing.DummyFixture
import org.testeditor.tcl.dsl.jvmmodel.AbstractTclGeneratorIntegrationTest

class MacroGeneratorIntegrationTest extends AbstractTclGeneratorIntegrationTest {

	@Before
	def void setup() {
		parseAml(DummyFixture.amlModel)
		parseTcl('''
			package com.example

			# MyMacroCollection

			## EmptyMacro
				template = "Do nothing"

			## EmptyNestedMacro
				template = "Do nothing nested"
				Macro: MyMacroCollection
				- Do nothing

			## EmptyMacroWithUnusedParameter
				template = "Do nothing with" ${unused}

			## ReadMacro
				template = "Read some values"
				Component: GreetingApplication
				- value = Read value from <bar>

			## WriteMacro
				template = "Set input to" ${value}
				Component: GreetingApplication
				- Set value of <Input> to @value

			## SleepMacro
				template = "Sleep for" ${x} "seconds"
				Component: GreetingApplication
				- Wait for @x seconds

			## SetValueAndWait
				template = "Read and write value and wait" ${seconds} "seconds"
				Component: GreetingApplication
				- value = Read value from <bar>
				Macro: MyMacroCollection
				- Set input to @value
				Macro: MyMacroCollection
				- Sleep for @seconds seconds

			## MacroWithNotExistingFixture
				template = "stop this"
				Component: GreetingApplication
				- Stop application
				- do something
		''')
	}

	@Test
	def void emptyMacroWithoutParameter() {
		// given
		val tcl = '''
			Macro: MyMacroCollection
			- Do nothing
		'''

		// when
		val generatedCode = tcl.parseAndGenerate

		// then
		generatedCode.replaceIDVarNumbering => [
			assertContains('''
				@Test
				public void execute() throws Exception {
				  try {
				    String IDvar=nextSubId("ID"); reporter.enter(TestRunReporter.SemanticUnit.SPECIFICATION_STEP, "step1", IDvar, TestRunReporter.Status.STARTED, variables("@", "SimpleTest.tcl:5-8"));
				    String IDvar=nextSubId("ID"); reporter.enter(TestRunReporter.SemanticUnit.MACRO_LIB, "MyMacroCollection", IDvar, TestRunReporter.Status.STARTED, variables("@", "SimpleTest.tcl:7-8"));
				    String IDvar=nextSubId("ID"); reporter.enter(TestRunReporter.SemanticUnit.STEP, "Do nothing", IDvar, TestRunReporter.Status.STARTED, variables("@", "SimpleTest.tcl:8"));
				    macro_MyMacroCollection_EmptyMacro(IDvar);
			'''.indent(1))

			assertContains('''
				private void macro_MyMacroCollection_EmptyMacro(final String id) throws Exception {
				  try {
				    String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.MACRO, "EmptyMacro", IDvar, TestRunReporter.Status.STARTED, variables("@", "__synthetic0.tcl:5-6"));
				    reporter.leave(TestRunReporter.SemanticUnit.MACRO, "EmptyMacro", IDvar, TestRunReporter.Status.OK, variables("@", "__synthetic0.tcl:5-6"));
			'''.indent(1))
		]
	}

	@Test
	def void emptyMacroWithUnusedParameter() {
		// given
		val tcl = '''
			Macro: MyMacroCollection
			- Do nothing with "x"
		'''

		// when
		val generatedCode = tcl.parseAndGenerate

		// then
		generatedCode.replaceIDVarNumbering => [
			assertContains('''
				macro_MyMacroCollection_EmptyMacroWithUnusedParameter("x", IDvar);
			'''.indent(2))

			assertContains('''
				private void macro_MyMacroCollection_EmptyMacroWithUnusedParameter(final String unused, final String id) throws Exception {
				  try {
				    String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.MACRO, "EmptyMacroWithUnusedParameter", IDvar, TestRunReporter.Status.STARTED, variables("@", "__synthetic0.tcl:13-14"));
				    reporter.leave(TestRunReporter.SemanticUnit.MACRO, "EmptyMacroWithUnusedParameter", IDvar, TestRunReporter.Status.OK, variables("@", "__synthetic0.tcl:13-14"));
				  } catch (AssertionError e) {
				    reporter.assertionExit(e);
				    finishedTestWith(TestRunReporter.Status.ERROR);
				    org.junit.Assert.fail(e.getMessage());
				  } catch (Exception e) {
				    reporter.exceptionExit(e);
				    finishedTestWith(TestRunReporter.Status.ABORTED);
				    org.junit.Assert.fail(e.getMessage());
				  }
				}
  			'''.indent(1))
		]
	}

	@Test
	def void repeatedMacroInvocation() {
		// given
		val tcl = '''
			Macro: MyMacroCollection
			- Read some values
			- Read some values
		'''

		// when
		val generatedCode = tcl.parseAndGenerate

		// then
		generatedCode.replaceIDVarNumbering => [
			assertContains('''
				macro_MyMacroCollection_ReadMacro(IDvar);
				reporter.leave(TestRunReporter.SemanticUnit.STEP, "Read some values", IDvar, TestRunReporter.Status.OK, variables("@", "SimpleTest.tcl:8"));
				String IDvar=nextSubId("ID"); reporter.enter(TestRunReporter.SemanticUnit.STEP, "Read some values", IDvar, TestRunReporter.Status.STARTED, variables("@", "SimpleTest.tcl:9"));
				macro_MyMacroCollection_ReadMacro(IDvar);
 			'''.indent(3))
			assertContains('''
			  private void macro_MyMacroCollection_ReadMacro(final String id) throws Exception {
			    try {
			      String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.MACRO, "ReadMacro", IDvar, TestRunReporter.Status.STARTED, variables("@", "__synthetic0.tcl:16-19"));
			      String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.COMPONENT, "GreetingApplication", IDvar, TestRunReporter.Status.STARTED, variables("@", "__synthetic0.tcl:18-19"));
			      String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.STEP, "value = Read value from <bar> [java.lang.String]", IDvar, TestRunReporter.Status.STARTED, variables("<bar>", "Locator: label.greet in __synthetic0.aml:123", "@", "__synthetic0.tcl:19"));
			      java.lang.String value = dummyFixture.getValue("label.greet");
			'''.indent(1))
		]
	}

	def private String replaceIDVarNumbering(String codeblock) {
		return codeblock.replaceAll('IDvar[0-9]*', 'IDvar')
	}

	@Test
	def void macroWithParameter() {
		// given
		val tcl = '''
			Macro: MyMacroCollection
			- Sleep for "5" seconds
		'''

		// when
		val generatedCode = tcl.parseAndGenerate

		// then
		generatedCode.replaceIDVarNumbering => [
			assertContains('''
				macro_MyMacroCollection_SleepMacro(5, IDvar);
			'''.indent(2))
			assertContains('''
				private void macro_MyMacroCollection_SleepMacro(final long x, final String id) throws Exception {
				  try {
				    String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.MACRO, "SleepMacro", IDvar, TestRunReporter.Status.STARTED, variables("@", "__synthetic0.tcl:26-29"));
				    String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.COMPONENT, "GreetingApplication", IDvar, TestRunReporter.Status.STARTED, variables("@", "__synthetic0.tcl:28-29"));
				    String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.STEP, "Wait for @x seconds", IDvar, TestRunReporter.Status.STARTED, variables("x", Long.toString(x), "@", "__synthetic0.tcl:29"));
				    dummyFixture.waitSeconds(x);
				    reporter.leave(TestRunReporter.SemanticUnit.STEP, "Wait for @x seconds", IDvar, TestRunReporter.Status.OK, variables("x", Long.toString(x), "@", "__synthetic0.tcl:29"));
				    reporter.leave(TestRunReporter.SemanticUnit.COMPONENT, "GreetingApplication", IDvar, TestRunReporter.Status.OK, variables("@", "__synthetic0.tcl:28-29"));
				    reporter.leave(TestRunReporter.SemanticUnit.MACRO, "SleepMacro", IDvar, TestRunReporter.Status.OK, variables("@", "__synthetic0.tcl:26-29"));
				  } catch (AssertionError e) {
				    reporter.assertionExit(e);
				    finishedTestWith(TestRunReporter.Status.ERROR);
				    org.junit.Assert.fail(e.getMessage());
				  } catch (org.testeditor.fixture.core.FixtureException e) {
				    reporter.fixtureExit(e);
				    finishedTestWith(TestRunReporter.Status.ABORTED);
				    org.junit.Assert.fail(e.getMessage());
				  } catch (Exception e) {
				    reporter.exceptionExit(e);
				    finishedTestWith(TestRunReporter.Status.ABORTED);
				    org.junit.Assert.fail(e.getMessage());
				  }
				}
    			'''.indent(1))
		]
	}

	@Test
	def void emptyNestedMacro() {
		// given
		val tcl = '''
			Macro: MyMacroCollection
			- Do nothing nested
		'''

		// when
		val generatedCode = tcl.parseAndGenerate

		// then
		generatedCode.replaceIDVarNumbering => [
			assertContains('''
				macro_MyMacroCollection_EmptyNestedMacro(IDvar);
			'''.indent(2))
			assertContains('''
				macro_MyMacroCollection_EmptyMacro(IDvar);
			'''.indent(1))
			assertContains('''
				String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.MACRO, "EmptyMacro", IDvar, TestRunReporter.Status.STARTED, variables("@", "__synthetic0.tcl:5-6"));
				reporter.leave(TestRunReporter.SemanticUnit.MACRO, "EmptyMacro", IDvar, TestRunReporter.Status.OK, variables("@", "__synthetic0.tcl:5-6"));
 			'''.indent(3))
		]
	}

	@Test
	def void nestedMacroWithMultipleVariables() {
		// given
		val tcl = '''
			Macro: MyMacroCollection
			- Read and write value and wait "5" seconds
		'''

		// when
		val generatedCode = tcl.parseAndGenerate

		// then
		generatedCode.replaceIDVarNumbering => [
			assertContains('''
				macro_MyMacroCollection_SetValueAndWait(5, IDvar);
			'''.indent(2))
			assertContains('''
				private void macro_MyMacroCollection_SetValueAndWait(final long seconds, final String id) throws Exception {
				  try {
				    String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.MACRO, "SetValueAndWait", IDvar, TestRunReporter.Status.STARTED, variables("@", "__synthetic0.tcl:31-38"));
				    String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.COMPONENT, "GreetingApplication", IDvar, TestRunReporter.Status.STARTED, variables("@", "__synthetic0.tcl:33-34"));
				    String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.STEP, "value = Read value from <bar> [java.lang.String]", IDvar, TestRunReporter.Status.STARTED, variables("<bar>", "Locator: label.greet in __synthetic0.aml:123", "@", "__synthetic0.tcl:34"));
				    java.lang.String value = dummyFixture.getValue("label.greet");
				    reporter.leave(TestRunReporter.SemanticUnit.STEP, "value = Read value from <bar> [java.lang.String]", IDvar, TestRunReporter.Status.OK, variables("value", value, "<bar>", "Locator: label.greet in __synthetic0.aml:123", "@", "__synthetic0.tcl:34"));
				    reporter.leave(TestRunReporter.SemanticUnit.COMPONENT, "GreetingApplication", IDvar, TestRunReporter.Status.OK, variables("@", "__synthetic0.tcl:33-34"));
				    String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.MACRO_LIB, "MyMacroCollection", IDvar, TestRunReporter.Status.STARTED, variables("@", "__synthetic0.tcl:35-36"));
				    String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.STEP, "Set input to @value", IDvar, TestRunReporter.Status.STARTED, variables("value", value, "@", "__synthetic0.tcl:36"));
				    macro_MyMacroCollection_WriteMacro(value, IDvar);
				    reporter.leave(TestRunReporter.SemanticUnit.STEP, "Set input to @value", IDvar, TestRunReporter.Status.OK, variables("value", value, "@", "__synthetic0.tcl:36"));
				    reporter.leave(TestRunReporter.SemanticUnit.MACRO_LIB, "MyMacroCollection", IDvar, TestRunReporter.Status.OK, variables("@", "__synthetic0.tcl:35-36"));
				    String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.MACRO_LIB, "MyMacroCollection", IDvar, TestRunReporter.Status.STARTED, variables("@", "__synthetic0.tcl:37-38"));
				    String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.STEP, "Sleep for @seconds seconds", IDvar, TestRunReporter.Status.STARTED, variables("seconds", Long.toString(seconds), "@", "__synthetic0.tcl:38"));
				    macro_MyMacroCollection_SleepMacro(seconds, IDvar);
				    reporter.leave(TestRunReporter.SemanticUnit.STEP, "Sleep for @seconds seconds", IDvar, TestRunReporter.Status.OK, variables("seconds", Long.toString(seconds), "@", "__synthetic0.tcl:38"));
				    reporter.leave(TestRunReporter.SemanticUnit.MACRO_LIB, "MyMacroCollection", IDvar, TestRunReporter.Status.OK, variables("@", "__synthetic0.tcl:37-38"));
				    reporter.leave(TestRunReporter.SemanticUnit.MACRO, "SetValueAndWait", IDvar, TestRunReporter.Status.OK, variables("@", "__synthetic0.tcl:31-38"));
				  } catch (AssertionError e) {
				    reporter.assertionExit(e);
				    finishedTestWith(TestRunReporter.Status.ERROR);
				    org.junit.Assert.fail(e.getMessage());
				  } catch (org.testeditor.fixture.core.FixtureException e) {
				    reporter.fixtureExit(e);
				    finishedTestWith(TestRunReporter.Status.ABORTED);
				    org.junit.Assert.fail(e.getMessage());
				  } catch (Exception e) {
				    reporter.exceptionExit(e);
				    finishedTestWith(TestRunReporter.Status.ABORTED);
				    org.junit.Assert.fail(e.getMessage());
				  }
				}
			'''.indent(1))

		]
	}

	@Test
	def void environmentVariableIsPassedToMacro() {
		// given
		val tcl = '''
			package com.example

			require public myEnvVar

			# SimpleTest
			* step1
				Macro: MyMacroCollection
				- Sleep for @myEnvVar seconds
		'''

		// when
		val tclModel = parseTcl(tcl, "SimpleTest.tcl")
		val generatedCode = tclModel.generate

		// then
		generatedCode => [
			assertContains('''
				try { Long.parseLong(env_myEnvVar); } catch (NumberFormatException nfe) { org.junit.Assert.fail("Parameter is expected to be of type = 'long' but a non coercible value = '"+env_myEnvVar.toString()+"' was passed through variable reference = 'myEnvVar'."); }
				macro_MyMacroCollection_SleepMacro(Long.parseLong(env_myEnvVar), IDvar2);
			'''.indent(3))
		]
	}

	override protected getTestHeader() '''
		«super.testHeader»

		* step1
	'''

	@Test
	def void testNotExistingFixtureInMacro() {
		// given
		val tcl = '''
			Macro: MyMacroCollection
			- stop this
		'''

		// when
		val generatedCode = tcl.parseAndGenerate


		// then
		generatedCode.replaceIDVarNumbering => [
			assertContains('''
				macro_MyMacroCollection_MacroWithNotExistingFixture(IDvar);
			'''.indent(2))
			assertContains('''
				String IDvar=nextSubId(id); reporter.enter(TestRunReporter.SemanticUnit.STEP, "Stop application", IDvar, TestRunReporter.Status.STARTED, variables("@", "__synthetic0.tcl:43"));
				dummyFixture.stopApplication();
				reporter.leave(TestRunReporter.SemanticUnit.STEP, "Stop application", IDvar, TestRunReporter.Status.OK, variables("@", "__synthetic0.tcl:43"));
				org.junit.Assert.fail("Template 'do something' cannot be resolved with any known macro/fixture. Please check your Macro 'MyMacroCollection' in line 44.");
			'''.indent(3))
		]
	}

}
