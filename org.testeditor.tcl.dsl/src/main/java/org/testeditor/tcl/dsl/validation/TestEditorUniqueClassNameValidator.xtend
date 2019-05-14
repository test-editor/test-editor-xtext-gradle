package org.testeditor.tcl.dsl.validation

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.xbase.validation.UniqueClassNameValidator

class TestEditorUniqueClassNameValidator extends UniqueClassNameValidator {

	@Check
	override void checkUniqueName(EObject root) {
		// disable default behavior
	}

}
