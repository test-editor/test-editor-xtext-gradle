package org.testeditor.tcl.dsl.tests.validation

import javax.inject.Inject
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.testing.validation.ValidationTestHelper
import org.junit.Before
import org.testeditor.tcl.TclModel
import org.testeditor.tcl.dsl.tests.parser.AbstractParserTest
import org.testeditor.tcl.util.ExampleAmlModel

class AbstractValidationTest extends AbstractParserTest {

	@Inject
	protected ValidationTestHelper validator
	
	@Inject 
	protected ExampleAmlModel amlModel

	@Before
	def void setupResourceSet() {
		resourceSet = amlModel.model.eResource.resourceSet as XtextResourceSet
	}
	
	
	def String reportableValidations(TclModel model) {
		return '''got: «validator.validate(model).map[toString].join('\n')»'''
	}
}