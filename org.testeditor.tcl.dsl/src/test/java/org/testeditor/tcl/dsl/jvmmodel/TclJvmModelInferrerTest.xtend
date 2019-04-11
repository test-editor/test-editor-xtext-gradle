package org.testeditor.tcl.dsl.jvmmodel

import org.junit.Before
import org.junit.Test
import org.testeditor.dsl.common.testing.DummyFixture

class TclJvmModelInferrerTest extends AbstractTclGeneratorIntegrationTest {
	
	@Before
	def void parseAmlModel() {
		parseAml(DummyFixture.amlModel).assertNoSyntaxErrors
	}

	@Test
	def void testGenerationForResolvedFixture() {
		//given
		val tclModel = parseTcl('''
			package com.example
			
			# MyTest
			
			* test something
			
			Component: GreetingApplication
			- Stop application
		''')
		tclModel.addToResourceSet

		//when
		val tclModelCode = tclModel.generate

		//then
		tclModelCode.assertContains('''
			    dummyFixture.stopApplication();
		'''.toString)
	}

	@Test
	def void testGenerationForUnresolvedFixtureAndWithResolvedFixture() {
		//given
		val tclModel = parseTcl('''
			package com.example
			
			# MyTest
			
			* test something
			
			Component: GreetingApplication
			- Stop application
			- do something "with Param"
		''')
		tclModel.addToResourceSet

		//when
		val tclModelCode = tclModel.generate
		
		//then
		tclModelCode.assertContains('''dummyFixture.stopApplication();''')
		tclModelCode.
			assertContains('''org.junit.Assert.fail("Template 'do something \"with Param\"' cannot be resolved with any known macro/fixture. Please check your Testcase 'MyTest' in line 9.");''')
	}

	@Test
	def void testGenerationForUnresolvedFixture() {
		//given
		val tclModel = parseTcl('''
			package com.example
			
			# MyTest
			
			* test something
			
			Component: GreetingApplication
			- do something
		''')
		tclModel.addToResourceSet

		//when
		val tclModelCode = tclModel.generate
		
		//then
		tclModelCode.assertContains(
			'''org.junit.Assert.fail("Template 'do something' cannot be resolved with any known macro/fixture. Please check your Testcase 'MyTest' in line 8.");'''.
				toString)
	}
	
	@Test
	def void testGeneratTionForMacroWithReturn() {
		//given
		parseTcl('''
			package com.example
			# MyMacroCollection
			## ReturnLongFromInteraction
			template = "get long"
			Component: GreetingApplication
			- result = Read long from <Input>
			- return result
		''', 'MyMacroCollection.tml').assertNoSyntaxErrors
		val tclModel = '''
			package com.example
			# MyTest
			* do some
				Macro: MyMacroCollection
				- longFromMacro = get long // call a macro that calls a fixture
		'''.toString.parseTcl
		tclModel.addToResourceSet

		//when
		val tclModelCode = tclModel.generate

		//then
		tclModelCode.assertContains('private long macro_MyMacroCollection_ReturnLongFromInteraction(final String id)')
		tclModelCode.assertContains('long macro_MyMacroCollection_ReturnLongFromInteraction_result = 0;')
		tclModelCode.assertContains('macro_MyMacroCollection_ReturnLongFromInteraction_result = result;')
		tclModelCode.assertContains('return macro_MyMacroCollection_ReturnLongFromInteraction_result;')
		
		tclModelCode.assertContains('longFromMacro = macro_MyMacroCollection_ReturnLongFromInteraction(')
	}
	
	
	// TODO code generation for runtime lookup of AML elements needs to be factored out of fixture call (because its super-ugly) 
	@Test
	def void testGeneratTionForMacroWithAmlElementParams() {
		//given
		'''
			package com.example
			
			# MyMacroCollection
			
			## MyMacro
			template = "send greetings to" ${field}
			Component: GreetingApplication
			- Type "Hello, World!" into <@field>
		'''.toString.parseTcl("MyMacroCollection.tml").assertNoSyntaxErrors

		val tclModel = '''
			package com.example
			
			# SampleTest
			* Sample Step
			Macro: MyMacroCollection
			- send greetings to "Input"
		'''.toString.parseTcl
		tclModel.addToResourceSet

		//when
		val tclModelCode = tclModel.generate

		//then
		tclModelCode.assertContains(
			'dummyFixture.typeInto(new java.util.HashMap<String, String>() {{ put("Input","text.input");put("Ok","button.ok"); }}.get(field), ' +
			'new java.util.HashMap<String, org.testeditor.dsl.common.testing.DummyLocatorStrategy>() {{ ' +
				'put("Input",org.testeditor.dsl.common.testing.DummyLocatorStrategy.ID);' +
				'put("Ok",org.testeditor.dsl.common.testing.DummyLocatorStrategy.ID); ' +
			'}}.get(field), "Hello, World!");'
		)
	}
	
	@Test
	def void testParameterizedTestCase() {
		// given
		DummyFixture.parameterizedTestAml.parseAml
		DummyFixture.amlModel.parseAml
		val tclModel = '''
			package com.example
			
			# MyTest
			
			Data: firstName, lastName, age
				Component: ParameterizedTesting
				- data = load data from "testData"
			
			* test something
			Component: GreetingApplication
			- Type @firstName into <Input>
		'''.toString.parseTcl('MyTest.tcl').assertNoSyntaxErrors
		
		// when
		val tclModelCode = tclModel.generate
		
		// then
		tclModelCode.assertContains('import org.junit.runner.RunWith;')
		tclModelCode.assertContains('import org.junit.runners.Parameterized;')
		tclModelCode.assertContains('@RunWith(Parameterized.class)')
		
		tclModelCode.assertContains('''
			@Parameterized.Parameters
			  public static Iterable<Object[]> data() {
			    try {
			      DummyFixture dummyFixture = new DummyFixture();
			      java.lang.Iterable<com.google.gson.JsonElement> data = dummyFixture.load("testData");
			      return data;
			    } catch (org.testeditor.fixture.core.FixtureException e) {
			      org.junit.Assert.fail(e.getMessage());
			    } catch (Exception e) {
			      org.junit.Assert.fail(e.getMessage());
			    }
			    return null;
			  }''')
		
		tclModelCode.assertContains('''
			@Parameterized.Parameter
			  public Object firstName;''')
		tclModelCode.assertContains('''
			@Parameterized.Parameter
			  public Object firstName;''')
		tclModelCode.assertContains('''
			@Parameterized.Parameter
			  public Object age;''')
	}
	
}
		