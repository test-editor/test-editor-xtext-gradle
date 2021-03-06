/*
 * generated by Xtext 2.15.0
 */
package org.testeditor.aml.dsl.tests

import com.google.inject.Inject
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Assert
import org.junit.Test
import org.junit.runner.RunWith
import org.testeditor.aml.AmlModel

@RunWith(XtextRunner)
@InjectWith(AmlInjectorProvider)
class AmlParsingTest {
	@Inject
	ParseHelper<AmlModel> parseHelper
	
	@Test
	def void loadModel() {
		val result = parseHelper.parse('''
            package org.testeditor
		''')
		Assert.assertNotNull(result)
		val errors = result.eResource.errors
		Assert.assertTrue('''Unexpected errors: «errors.join(", ")»''', errors.isEmpty)
	}
}
