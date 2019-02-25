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
	def void testGenerationForMacroWithReturn() {
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
		tclModelCode.assertContains('return result;')
		tclModelCode.assertContains('longFromMacro = macro_MyMacroCollection_ReturnLongFromInteraction(')
	}
	
}
		