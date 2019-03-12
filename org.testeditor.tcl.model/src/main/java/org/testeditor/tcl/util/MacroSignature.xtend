package org.testeditor.tcl.util

import java.util.List
import org.eclipse.xtend.lib.annotations.Data
import org.testeditor.aml.TemplateText
import org.testeditor.aml.TemplateVariable
import org.testeditor.tcl.Macro
import org.testeditor.tcl.StepContentElement
import org.testeditor.tcl.StepContentElementReference
import org.testeditor.tcl.TestStep
import org.testeditor.tcl.VariableReference
import org.testeditor.tsl.StepContentValue
import org.testeditor.tsl.StepContentVariable

abstract class MacroSignature {
	static def MacroSignature signature(TestStep step) {
		return new CompositeMacroSignature(step.contents.map[
			switch (it) {
				StepContentElement | StepContentElementReference: new MacroSignatureElementParameter
				StepContentVariable: new MacroSignatureValueParameter
				VariableReference: new MacroSignatureValueParameter
				StepContentValue: new MacroSignatureText(value)
				default: throw new IllegalArgumentException("Unhandled content: " + it)
			}
		])
	}
	
	static def MacroSignature signature(Macro macro, (TemplateVariable)=>Boolean isElementParameter) {
		return new CompositeMacroSignature(macro.template.contents.map[
			switch (it) {
				TemplateVariable: #[new MacroSignatureUndeterminedParameter[
					return if (isElementParameter.apply(it)) {
						new MacroSignatureElementParameter
					} else {
						new MacroSignatureValueParameter
					}
				]]  as List<? extends MacroSignature>
				TemplateText: value.split('\\s+').map[new MacroSignatureText(it)]
			}
		].flatten)
	}
	
	abstract def String normalize()
	
	abstract def boolean matches(MacroSignature signature)
	
	abstract def MacroSignature resolve()
	
	protected def String removeWhitespaceBeforePunctuation(String input) {
		return input.replaceAll('''\s+(\.|\?)''', "$1")
	}
}

@Data class CompositeMacroSignature extends MacroSignature {
	Iterable<MacroSignature> elements
	
	override normalize() {
		return elements.map[normalize].join(' ').removeWhitespaceBeforePunctuation
	}
	
	override matches(MacroSignature signature) {
		return if (signature instanceof CompositeMacroSignature) {
			elements.matches(signature.elements)
		} else {
			false
		}
	}
	
	private def boolean matches(Iterable<MacroSignature> left, Iterable<MacroSignature> right) {
		return (left.nullOrEmpty && right.nullOrEmpty) ||
				left?.head?.matches(right?.head) && left?.tail?.matches(right?.tail)
	}
	
	override resolve() {
		elements.forEach[resolve]
		return this
	}
	
}

@Data class MacroSignatureText extends MacroSignature {
	String text
	
	override normalize() {
		return text.trim
	}
	
	override matches(MacroSignature signature) {
		return normalize == signature.normalize
	}
	
	override resolve() {
		return this
	}
	
}

abstract class MacroSignatureParameter extends MacroSignature {
	override resolve() {
		return this
	}
}

class MacroSignatureValueParameter extends MacroSignatureParameter {
	
	override normalize() {
		return '""'
	}
	
	override matches(MacroSignature signature) {
		return signature instanceof MacroSignatureValueParameter
	}
	
}

class MacroSignatureElementParameter extends MacroSignatureParameter {
	
	override normalize() {
		return '<>'
	}
	
	override matches(MacroSignature signature) {
		return signature instanceof MacroSignatureElementParameter
	}
}

@Data class MacroSignatureUndeterminedParameter extends MacroSignatureParameter {
	()=>MacroSignatureParameter resolve
	transient MacroSignatureParameter resolvedParameter = null
	
	override normalize() {
		return if (resolvedParameter === null) {
			''
		} else {
			resolvedParameter.normalize
		}
	}
	
	override matches(MacroSignature signature) {
		return if (resolvedParameter === null) {
			signature instanceof MacroSignatureParameter
		} else {
			resolvedParameter.matches(signature)
		}
	}
	
	override MacroSignatureParameter resolve() {
		resolvedParameter = resolve.apply
		return resolvedParameter
	}
}
