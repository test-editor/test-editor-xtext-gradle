package org.testeditor.tcl.dsl.tests.formatter

import org.junit.Ignore
import org.junit.Test

@Ignore("formatting is broken because of newline elements in the grammar. formatter is currently not in use (by the web frontend)!")
class TestStepFormatterTest extends AbstractTclFormatterTest {

	// TODO remove useNodeModel = false below once https://github.com/eclipse/xtext-core/issues/164 is resolved

	val prefix = '''
		package com.example
		
		import a.b.c
		import c.d.e
		
		require freq, breq
		
		# testCase

	'''

	@Test
	def void formatLineBreaks() {
		assertFormatted [
			expectation = prefix + '''
				* specification
				
					Component: some
				
					Mask: other
				
				* next spec
			'''

			toBeFormatted = prefix + '''
				* specification
				Component: some
				Mask: other
				* next spec
			'''
			useNodeModel = true
			useSerializer = false
			
		]
	}

	@Test
	def void formatWhitespaces() {
		assertFormatted [
			expectation = prefix + '''
				* specification
				
					Component: some
				
					Mask: other
				
				* next spec
			'''

			toBeFormatted = prefix + '''
				* specification
								Component				:				some			
				  Mask     :      other   
				* next spec
			'''
		]
	}
	@Test
	def void formatLineBreaksTml() {
		assertFormatted [
			useNodeModel = false
			expectation = prefix + '''
				* spec
				
					Component: dummyComponent
					- step withspaces "string" with <ele> and @some."key".
					- next step
				'''

			toBeFormatted = prefix + '''
				* spec
				Component: dummyComponent
				- step
				withspaces
				"string"
				with
				<ele> and
				@some."key".
				- next
				step
			'''
		]
	}

	@Test
	def void formatWhitespacesTml() {
		assertFormatted [
			useNodeModel = false
			expectation = prefix + '''
				* spec

					Component: component
					- step withspaces "string" with <ele> and @some."key".
					- next step
			'''

			toBeFormatted = prefix + '''
				   * spec
				   Component :    	component   
				   - step    			withspaces		    	"string"				with				<ele>				and
				@some				.		"key"    .	
					-  next    step
			'''
		]
	}

	@Test
	def void formatPunctuation() {
		assertFormatted [
			expectation = prefix + '''
				* spec

					Component: component
					- Is <Input> visible?
					- Is <Input> visible?
			'''

			toBeFormatted = prefix + '''
				* spec
				
					Component: component
					- Is <Input> visible       ?
					- Is <Input> visible
					    ?
			'''
		]
	}

}
