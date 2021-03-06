theory TFGCasper

imports Main HOL.Real CBCCasper LatestMessage SafetyOracle

begin

(* Section 4.4: Casper the Friendly GHOST *)
(* Definition 4.23: Blocks *)
type_synonym block = consensus_value

locale GhostParams = Params +
  (* Definition 4.23: Previous block resolver *)
  fixes B :: "block set"
  fixes genesis :: block
  (* Definition 4.24: Previous block resolver *)
  and prev :: "block \<Rightarrow> block"

(* Definition 4.25: n'th generation ancestor block *)
fun (in GhostParams) n_cestor :: "block * nat \<Rightarrow> block"
  where
    "n_cestor (b, 0) = b"
  | "n_cestor (b, n) = n_cestor (prev b, n-1)"

(* Definition 4.26: Blockchain membership *)
fun (in GhostParams) blockchain_membership :: "block \<Rightarrow> block \<Rightarrow> bool" (infixl "\<downharpoonright>" 70)
  where
    "b1 \<downharpoonright> b2 = (\<exists> n. n \<in> \<nat> \<and> b1 = n_cestor (b2, n))"

notation (ASCII)
  comp  (infixl "blockchain_membership" 70)

(* Definition 4.27: Score of a block *)
definition (in GhostParams) score :: "state \<Rightarrow> block \<Rightarrow> real"
  where
    "score \<sigma> b = sum W {v \<in> observed \<sigma>. \<exists> b' \<in> B. b' \<in> (latest_estimates_from_non_equivocating_validators \<sigma> v) \<and> (b \<downharpoonright> b')}"

(* Definition 4.28: Children *)
definition (in GhostParams) children :: "block * state \<Rightarrow> block set"
  where
    "children = (\<lambda>(b, \<sigma>). {b' \<in> est `\<sigma>. b = prev b'})"

(* Definition 4.29: Best Children *)
definition (in GhostParams) best_children :: "block * state \<Rightarrow>  block set"
  where
    "best_children = (\<lambda> (b, \<sigma>). {arg_max_on (score \<sigma>) (children (b, \<sigma>))})"

(* Definition 4.30: GHOST *)
(* NOTE: well-sortedness error occurs in code generation *)
function (in GhostParams) GHOST :: "(block set * state) => block set"
  where
    "GHOST (b_set, \<sigma>) =
      (\<Union> b \<in> {b \<in> b_set. children (b, \<sigma>) \<noteq> \<emptyset>}. GHOST (best_children (b, \<sigma>), \<sigma>))
       \<union> {b \<in> b_set. children (b, \<sigma>) = \<emptyset>}"
  by auto

(* Definition 4.31: Casper the Friendly Ghost *)
definition (in GhostParams) GHOST_estimator :: "state \<Rightarrow> block set"
  where
    "GHOST_estimator \<sigma> = GHOST ({genesis}, \<sigma>) \<union> (\<Union> b \<in> GHOST ({genesis}, \<sigma>). children (b, \<sigma>))"

(* Definition 4.32: Example non-trivial properties of consensus values *)
abbreviation (in GhostParams) P :: "consensus_value_property set"
  where
    "P \<equiv> {p. \<exists>!b \<in> B. \<forall>b' \<in> B. (b \<downharpoonright> b' \<longrightarrow> p b' = True) \<and> \<not> (b \<downharpoonright> b' \<longrightarrow> p b' = False)}"

(* Locale for proofs *)
locale Ghost = GhostParams + Protocol +
  assumes prev_type : "\<forall> b. b \<in> B \<longleftrightarrow> prev b \<in> B"
  and block_is_consensus_value : "B = C"
  and ghost_is_estimator : "\<epsilon> = GHOST_estimator"
  and genesis_type : "genesis \<in> C"

lemma (in Ghost) children_type :
  "\<forall> b \<sigma>. b \<in> B \<and> \<sigma> \<in> \<Sigma> \<longrightarrow>  children (b, \<sigma>) \<subseteq> B"
  apply (simp add: children_def)
  using Ghost_axioms Ghost_axioms_def Ghost_def by auto

lemma (in Ghost) best_children_type :
  "\<forall> b \<sigma>. b \<in> B \<and> \<sigma> \<in> \<Sigma> \<longrightarrow>  best_children (b, \<sigma>) \<subseteq> B"
  apply (simp add: best_children_def arg_max_on_def arg_max_def is_arg_max_def)
  apply auto 
  oops

lemma (in Ghost) GHSOT_type :
  "\<forall> \<sigma> b_set. \<sigma> \<in> \<Sigma> \<and> b_set \<subseteq> B \<longrightarrow>  GHOST(b_set, \<sigma>) \<subseteq> B"
  oops

lemma (in GhostParams) GHOST_is_valid_estimator : 
  "(\<forall> b. b \<in> B \<longleftrightarrow> prev b \<in> B) \<and> B = C \<and> genesis \<in> C 
  \<Longrightarrow> is_valid_estimator GHOST_estimator"
  apply (simp add: is_valid_estimator_def GhostParams.GHOST_estimator_def)
  oops

lemma (in Ghost) block_membership_property_is_majority_driven :
  "\<forall> p \<in> P. is_majority_driven p"
  apply (simp add: is_majority_driven_def)
  (* by (metis DiffE Pow_iff is_valid_estimator_def \<epsilon>_type block_is_consensus_value subsetCE) *)
  oops

lemma (in Ghost) block_membership_property_is_max_driven :
  "\<forall> p \<in> P. is_max_driven p"
  apply (simp add: is_max_driven_def)
  (* FIXME: Timeout *)
  (* by (metis DiffE Nats_0 ghost_is_estimator) *)
  oops

end
